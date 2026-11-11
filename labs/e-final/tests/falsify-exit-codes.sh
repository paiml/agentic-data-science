#!/usr/bin/env bash
# falsify-exit-codes.sh : fix for #195 review blockers B1 and B2 (fc Opus lane, 16:18Z). Needs docker.
# B1: SKIP_GRADE=1 must NOT be GREEN with exit 0: the card verdict is SKIPPED and the exit is nonzero (3).
# B2: dirty image inputs (documented exit 2) must exit 2 before any build, not 0.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd); lab=$(cd "$here/.." && pwd); repo=$(cd "$lab/../.." && pwd)
T=$(mktemp -d "$repo/.lab-exit-XXXXXX"); probe="$lab/image/.dirty-probe"
trap 'rm -rf "${T:?}" "${probe:?}"' EXIT; chmod 755 "$T"
bad=0
touch "$probe"
PORT=18096 OUT="$T/o2" SKIP_GRADE=1 bash "$here/lab-preview.sh" c05 e-final >"$T/b2.out" 2>&1; rc=$?
echo "B2 dirty image inputs: exit=$rc (want 2)"; [ "$rc" -eq 2 ] && grep -q 'image inputs dirty' "$T/b2.out" || bad=1
rm -f "${probe:?}"
PORT=18096 OUT="$T/o1" SKIP_GRADE=1 bash "$here/lab-preview.sh" c05 e-final >"$T/b1.out" 2>&1; rc=$?
v=$(jq -r .verdict "$T/o1/c05/e-final/card.json" 2>/dev/null)
echo "B1 SKIP_GRADE=1: exit=$rc (want 3), verdict=$v (want SKIPPED)"; [ "$rc" -eq 3 ] && [ "$v" = SKIPPED ] || bad=1
[ "$bad" -eq 0 ] && { echo "falsify-exit-codes: GREEN"; exit 0; }
echo "falsify-exit-codes: RED"; exit 1
