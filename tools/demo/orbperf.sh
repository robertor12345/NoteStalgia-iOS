#!/bin/zsh
# Orb performance probe on the booted simulator: tools/demo/orbperf.sh <label> [extra launch args…]
# Launches the installed app straight to sign-in with the frame monitor on, then reports: host CPU of
# the app + render server, the screen recorder's delivered fps / frame gaps, the app's main-thread
# busy %, and the app's own `orb.frames` log (display-link fps, hitches, shell draws, nebula canvas ms).
set -uo pipefail
REPO="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$REPO"; WORK="${DEMO_WORKDIR:-$REPO/.demo-work}"; mkdir -p "$WORK"
label="${1:-probe}"; shift || true
UDID="${DEMO_UDID:-$(xcrun simctl list devices booted | grep -o '[0-9A-F-]\{36\}' | head -1)}"
[[ -n "$UDID" ]] || { echo "boot a simulator first"; exit 1; }
pkill -f "recordVideo" 2>/dev/null
xcrun simctl launch --terminate-running-process "$UDID" com.notestalgia.ios -NoteStalgiaDemoSkipLaunch YES \
  -NoteStalgiaDemoAudioLog YES -NoteStalgiaDemoFrameLog YES "$@" > /dev/null
sleep 8
echo "== $label: host CPU (4 s) =="
top -l 5 -s 1 -stats pid,cpu,command 2>/dev/null | grep -E "NoteStalgia-iOS|backboardd|SpringBoard" \
  | awk '{cpu[$3]+=$2; n[$3]++} END {for (k in cpu) printf "  %5.1f%%  %s\n", cpu[k]/n[k], k}' | sort -rn
echo "== $label: screen recorder, 8 s =="
OUT="$WORK/orb_$label.mp4"; rm -f "$OUT"
(xcrun simctl io "$UDID" recordVideo --codec=h264 --force "$OUT" > /dev/null 2>&1 &)
sleep 9; pkill -INT -f "recordVideo"; sleep 4
"$WORK/bin/fps" "$OUT" 0.5 2>&1 | tail -1 | sed 's/^/  /'
echo "== $label: app main thread (5 s) =="
PID=$(pgrep -f "NoteStalgia-iOS.app/NoteStalgia-iOS" | head -1)
sample "$PID" 5 -mayDie -file "$WORK/prof_orb_$label.txt" > /dev/null 2>&1
python3 tools/demo/anal.py "$WORK/prof_orb_$label.txt" NoteStalgia-iOS 6 2>/dev/null | sed -n '1p;3,8p' | sed 's/^/  /'
echo "== $label: in-app frame monitor (last windows) =="
C=$(xcrun simctl get_app_container "$UDID" com.notestalgia.ios data 2>/dev/null)
python3 - "$C/Documents/demo-audio-log.jsonl" <<'PY'
import json, sys
rows=[json.loads(l) for l in open(sys.argv[1]) if l.strip()]
f=[r for r in rows if r.get("event")=="orb.frames"][-8:]
for r in f:
    print(f"  display {r['displayFps']:5.1f} fps (max {r['maxDisplayFps']})  hitches {r['hitches']:2d}  shell draws {r['shellDrawsPerSecond']:5.1f}/s  canvas avg {r['canvasAvgMs']:.2f} ms max {r['canvasMaxMs']:.2f} ms")
PY
