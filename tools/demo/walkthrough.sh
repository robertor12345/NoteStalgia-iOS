#!/bin/zsh
# Record one scripted walkthrough end to end.
#
#   tools/demo/walkthrough.sh testResidentSessionWalkthrough [take-name]
#   tools/demo/walkthrough.sh list
#
# Builds the app + DemoUITests, starts record.sh, runs the one test on the booted simulator
# (DEMO_UDID), then stops the recording. DEMO_PACE=1.3 stretches every pause by 1.3×.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/../.." && pwd)"; cd "$REPO"
test="${1:-}"; take="${2:-$test}"
if [[ "$test" == "list" || -z "$test" ]]; then
  grep -o 'func test[A-Za-z]*' DemoUITests/DemoWalkthroughUITests.swift | sed 's/func //'; exit 0
fi
UDID="${DEMO_UDID:-$(xcrun simctl list devices booted | grep -o '[0-9A-F-]\{36\}' | head -1)}"
[[ -n "$UDID" ]] || { echo "boot a simulator first (or set DEMO_UDID)"; exit 1; }
CONFIG="${DEMO_CONFIG:-Release}"   # DEMO_CONFIG=Debug for a quicker check of the script itself
xcrun simctl bootstatus "$UDID" -b > /dev/null 2>&1 || true   # xcodebuild shuts the sim down after a test
xcodegen generate -q
echo "building app + UI tests…"
xcodebuild -project NoteStalgia-iOS.xcodeproj -scheme NoteStalgia-iOS -configuration "$CONFIG" \
  -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath .derivedData build-for-testing -quiet
MARKERS=/tmp/notestalgia-demo-markers.log; rm -f "$MARKERS"
tools/demo/record.sh start "$take"
set +e
TEST_RUNNER_DEMO_PACE="${DEMO_PACE:-1}" TEST_RUNNER_DEMO_MARKERS_FILE="$MARKERS" xcodebuild -project NoteStalgia-iOS.xcodeproj -scheme NoteStalgia-iOS -configuration "$CONFIG" \
  -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath .derivedData test-without-building \
  -only-testing:"NoteStalgiaDemoUITests/DemoWalkthroughUITests/$test" -quiet 2>&1 | grep -E "Test Case|error|passed|failed" | tail -5
test_status=${pipestatus[1]}
set -e
tools/demo/record.sh stop "$take"

# xcodebuild spends ~1 minute installing the test runner before the app appears. Trim that dead
# lead-in using the app's own demo log (first phase event = sign-in), keeping 1.5 s of title screen.
WORK="${DEMO_WORKDIR:-$REPO/.demo-work}"; TAKE="$WORK/takes/$take.mp4"
# xcodebuild reinstalls the app (new data container) and often shuts the simulator down afterwards,
# so resolve the container only now, after making sure the device is booted.
xcrun simctl bootstatus "$UDID" -b > /dev/null 2>&1 || true
CONTAINER=$(xcrun simctl get_app_container "$UDID" com.notestalgia.ios data 2>/dev/null || true)
rm -rf .derivedData/Logs/Test/*.xcresult 2>/dev/null || true   # xcresult bundles grow by hundreds of MB per run
if [[ -n "$CONTAINER" && -f "$CONTAINER/Documents/demo-audio-log.jsonl" && -f "$WORK/takes/$take.start" ]]; then
  # First moment worth keeping: the earliest app log event or script marker (the story takes mark
  # "open" the instant the app launches, before any phase change is logged).
  FIRST=$(python3 - "$CONTAINER/Documents/demo-audio-log.jsonl" "$MARKERS" <<'PY'
import json, sys, os
ts = [json.loads(l)["t"] for l in open(sys.argv[1]) if l.strip()]
if os.path.exists(sys.argv[2]):
    ts += [float(l.split("|")[0]) for l in open(sys.argv[2]) if "|" in l]
print(min(ts))
PY
)
  START=$(cat "$WORK/takes/$take.start")
  TRIM=$(python3 -c "print(max(0.0, float('$FIRST') - float('$START') - 4.0))")
  # Exact-seek trim plus a compact re-encode (hardware H.264, half resolution — the compositor shows
  # the screen at 695×1000 px, so nothing visible is lost and a five-minute take drops to ~250 MB).
  if ffmpeg -hide_banner -loglevel error -y -ss "$TRIM" -i "$TAKE" -vf "scale=-2:2000" -c:v h264_videotoolbox -b:v 7M -an \
       "$WORK/takes/$take.trimmed.mp4"; then
    mv -f "$WORK/takes/$take.trimmed.mp4" "$TAKE"
    echo "trimmed ${TRIM}s of lead-in and re-encoded"
  else
    TRIM=0
  fi
  # The app's event log (phases, music, chimes) plus the numbers that map its clock onto the take:
  # video_time = (event_t - start) - trim. The assembly step uses this for chapter cuts and captions.
  cp "$CONTAINER/Documents/demo-audio-log.jsonl" "$WORK/takes/$take.log.jsonl"
  [[ -f "$MARKERS" ]] && cp "$MARKERS" "$WORK/takes/$take.markers.log"
  printf '{"start": %s, "trim": %s, "firstEvent": %s}\n' "$START" "$TRIM" "$FIRST" > "$WORK/takes/$take.sync.json"
fi
echo "walkthrough exit $test_status → $TAKE"
