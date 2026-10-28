#!/bin/zsh
# Reset the deployed demo backend before recording: the model forgets everything it learned, songs added
# ad hoc (artist expansions, device searches) are dropped, and the demo residents, sessions and group
# history are re-seeded over whatever the iPads pushed. Demo data only — see the backend's ADR 0001.
#
#   tools/demo/reset-backend.sh                      # deployed Worker (seed token from worker/.deploy/seed-token)
#   SEED_URL=http://localhost:8787 tools/demo/reset-backend.sh   # local wrangler dev
set -euo pipefail
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
BACKEND="${NOTESTALGIA_BACKEND:-$REPO/../NoteStalgia-Backend}"
WORK="${DEMO_WORKDIR:-$REPO/.demo-work}"; mkdir -p "$WORK"
# Node 26 on this Mac rejects Cloudflare's certificate chain without the macOS system roots.
PEM="$WORK/system-roots.pem"
[[ -s "$PEM" ]] || security find-certificate -a -p /System/Library/Keychains/SystemRootCertificates.keychain > "$PEM"
URL="${SEED_URL:-https://notestalgia-api.fitraclesub.workers.dev}"
TOKEN="${SEED_TOKEN:-}"
[[ -n "$TOKEN" || ! -f "$BACKEND/worker/.deploy/seed-token" ]] || TOKEN="$(cat "$BACKEND/worker/.deploy/seed-token")"
cd "$BACKEND/worker"
NODE_EXTRA_CA_CERTS="$PEM" SEED_URL="$URL" SEED_TOKEN="$TOKEN" SEED_RESET=1 npm run --silent seed:remote
echo "reset-backend: $URL re-seeded (model + ad-hoc songs cleared)"
