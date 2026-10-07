#!/bin/zsh
# Timestamped marker while recording by hand: tools/demo/mark.sh "<label>"  → $DEMO_WORKDIR/markers.log
# (The scripted walkthroughs don't need markers — their pacing is in the test.)
REPO="$(cd "$(dirname "$0")/../.." && pwd)"; WORK="${DEMO_WORKDIR:-$REPO/.demo-work}"; mkdir -p "$WORK"
echo "$(date +%s.%N)|$1" >> "$WORK/markers.log"; tail -1 "$WORK/markers.log"
