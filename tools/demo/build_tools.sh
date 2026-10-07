#!/bin/zsh
# Compile the two Swift helpers used by the legacy compositor pipeline into $DEMO_WORKDIR/bin.
REPO="$(cd "$(dirname "$0")/../.." && pwd)"; WORK="${DEMO_WORKDIR:-$REPO/.demo-work}"; mkdir -p "$WORK/bin"
swiftc -O -o "$WORK/bin/render" "$REPO/tools/demo/pipeline/render.swift"
swiftc -O -o "$WORK/bin/fps" "$REPO/tools/demo/pipeline/fps.swift"
ls -la "$WORK/bin"
