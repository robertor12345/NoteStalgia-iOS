#!/bin/zsh
# CPU sample of the running app on the simulator: tools/demo/profile.sh <label> [seconds] [rows]
# Writes $DEMO_WORKDIR/prof_<label>.txt and prints the main-thread summary (anal.py).
REPO="$(cd "$(dirname "$0")/../.." && pwd)"; WORK="${DEMO_WORKDIR:-$REPO/.demo-work}"; mkdir -p "$WORK"
PID=$(pgrep -f "NoteStalgia-iOS.app/NoteStalgia-iOS" | head -1)
[[ -n "$PID" ]] || { echo "app not running"; exit 1; }
sample "$PID" "${2:-6}" -mayDie -file "$WORK/prof_$1.txt" > /dev/null 2>&1
python3 "$REPO/tools/demo/anal.py" "$WORK/prof_$1.txt" NoteStalgia-iOS "${3:-16}"
