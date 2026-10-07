#!/bin/zsh
# Record the booted simulator, with the app's real audio when a loopback device is present.
#
#   tools/demo/record.sh start <take>     start video (simctl) + audio (ffmpeg via BlackHole) capture
#   tools/demo/record.sh stop  <take>     stop both and mux to $DEMO_WORKDIR/takes/<take>.mp4
#
# Env: DEMO_UDID (default: first booted simulator), DEMO_WORKDIR (default: <repo>/.demo-work),
#      DEMO_AUDIO_DEVICE (default: "BlackHole 2ch"; set empty to skip audio),
#      DEMO_AUDIO_OFFSET (seconds to shift audio, default 0 — tune if lips/chimes drift).
# Audio: set the Mac's output device to a Multi-Output Device containing BlackHole 2ch + your
# speakers (Audio MIDI Setup) so you still hear the take while ffmpeg records the loopback.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="${DEMO_WORKDIR:-$REPO/.demo-work}"; TAKES="$WORK/takes"; mkdir -p "$TAKES"
UDID="${DEMO_UDID:-$(xcrun simctl list devices booted | grep -o '[0-9A-F-]\{36\}' | head -1)}"
AUDIO_DEVICE="${DEMO_AUDIO_DEVICE-BlackHole 2ch}"
cmd="${1:-}"; take="${2:-take}"
[[ -n "$UDID" ]] || { echo "no booted simulator (set DEMO_UDID)"; exit 1; }

case "$cmd" in
  start)
    rm -f "$TAKES/$take.raw.mp4" "$TAKES/$take.audio.m4a"
    xcrun simctl io "$UDID" recordVideo --codec=h264 --force "$TAKES/$take.raw.mp4" > "$TAKES/$take.video.log" 2>&1 &
    echo $! > "$TAKES/$take.video.pid"
    # ffmpeg exits non-zero after listing devices; don't let pipefail turn a match into "not found".
    if [[ -n "$AUDIO_DEVICE" ]] && { ffmpeg -hide_banner -f avfoundation -list_devices true -i "" 2>&1 || true; } | grep -q "$AUDIO_DEVICE"; then
      ffmpeg -hide_banner -loglevel error -f avfoundation -i ":$AUDIO_DEVICE" -c:a aac -b:a 192k "$TAKES/$take.audio.m4a" > "$TAKES/$take.audio.log" 2>&1 &
      echo $! > "$TAKES/$take.audio.pid"
      echo "recording video + audio ($AUDIO_DEVICE) → $TAKES/$take.*"
    elif [[ -z "$AUDIO_DEVICE" ]]; then
      echo "recording video only (audio capture disabled)"
    else
      echo "recording video only — no '$AUDIO_DEVICE' input yet (install blackhole-2ch + reboot), or rebuild audio with pipeline/mix_v2.py from the demo log"
    fi
    date +%s.%N > "$TAKES/$take.start"
    ;;
  stop)
    for kind in audio video; do
      if [[ -f "$TAKES/$take.$kind.pid" ]]; then kill -INT "$(cat "$TAKES/$take.$kind.pid")" 2>/dev/null || true; rm -f "$TAKES/$take.$kind.pid"; fi
    done
    sleep 4
    if [[ -f "$TAKES/$take.audio.m4a" ]]; then
      ffmpeg -hide_banner -loglevel error -y -i "$TAKES/$take.raw.mp4" -itsoffset "${DEMO_AUDIO_OFFSET:-0}" -i "$TAKES/$take.audio.m4a" \
        -map 0:v -map 1:a -c:v copy -c:a copy -shortest "$TAKES/$take.mp4" && rm -f "$TAKES/$take.raw.mp4"
    else
      mv -f "$TAKES/$take.raw.mp4" "$TAKES/$take.mp4"
    fi
    ls -la "$TAKES/$take.mp4"
    ;;
  *) echo "usage: record.sh start|stop <take>"; exit 2 ;;
esac
