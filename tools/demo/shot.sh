#!/bin/zsh
# Screenshot the booted simulator: tools/demo/shot.sh <name>  → $DEMO_WORKDIR/shots/<name>.png (+ a 1000px preview)
REPO="$(cd "$(dirname "$0")/../.." && pwd)"; WORK="${DEMO_WORKDIR:-$REPO/.demo-work}"; mkdir -p "$WORK/shots"
UDID="${DEMO_UDID:-$(xcrun simctl list devices booted | grep -o '[0-9A-F-]\{36\}' | head -1)}"
xcrun simctl io "$UDID" screenshot "$WORK/shots/$1.png" > /dev/null 2>&1
sips -Z 1000 "$WORK/shots/$1.png" --out "$WORK/shots/$1.preview.png" > /dev/null 2>&1
echo "$WORK/shots/$1.png"
