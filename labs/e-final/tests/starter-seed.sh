#!/usr/bin/env bash
# The lab image ships the starter and start.sh seeds it into the workspace (a learner who opens the lab must see Mean.lean).
# Usage: starter-seed.sh [DOCKERFILE [START.SH]]   (optional paths let the falsifier check scratch copies)
set -uo pipefail
here=$(cd "$(dirname "$0")/.." && pwd); d="${1:-$here/image/Dockerfile}"; s="${2:-$here/image/start.sh}"
[ -s "$here/starter/Mean.lean" ] || { echo "FAIL: starter/Mean.lean is missing or empty"; exit 1; }
cmp -s "$here/starter/Mean.lean" "$here/image/starter/Mean.lean" || { echo "FAIL: image/starter/Mean.lean differs from starter/Mean.lean"; exit 1; }
grep -q '^COPY --chown=coder:coder starter/ /opt/ads-lab/starter/' "$d" || { echo "FAIL: Dockerfile does not COPY starter/ into the image"; exit 1; }
grep -q 'cp -n /opt/ads-lab/starter/Mean.lean /home/coder/project/Mean.lean' "$s" || { echo "FAIL: start.sh does not seed Mean.lean into /home/coder/project"; exit 1; }
echo "PASS: starter ships in the image and start.sh seeds it (cp -n)"
