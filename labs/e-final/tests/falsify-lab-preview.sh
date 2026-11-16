#!/usr/bin/env bash
# falsify-lab-preview.sh : D48 item 6. (1) Change one Dockerfile line -> new digest -> the card shows image_digest RED (drift).
# (2) Remove one solution step -> the in-container grader fails the solution -> the card is RED. Needs docker + the cached image.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd); lab=$(cd "$here/.." && pwd); repo=$(cd "$lab/../.." && pwd)
T=$(mktemp -d "$repo/.lab-falsify-XXXXXX"); trap 'rm -rf "$T"' EXIT; chmod 755 "$T"
base=$(PORT=18095 OUT="$T/o0" SKIP_GRADE=1 bash "$here/lab-preview.sh" c05 e-final >/dev/null 2>&1; jq -r .digest "$T/o0/c05/e-final/card.json")
[ -n "$base" ] || { echo "falsify: NOT MEASURED (no baseline digest)"; exit 2; }
jq -n --arg d "$base" '{image_digest:$d}' > "$T/coursera.json"
PORT=18095 OUT="$T/o1" SKIP_GRADE=1 COURSERA_JSON="$T/coursera.json" bash "$here/lab-preview.sh" c05 e-final >/dev/null 2>&1; same=$?
cp -r "$lab/image" "$T/image-variant"; printf '\nENV LAB_PREVIEW_FALSIFIER=1\n' >> "$T/image-variant/Dockerfile"
PORT=18095 OUT="$T/o2" SKIP_GRADE=1 COURSERA_JSON="$T/coursera.json" IMAGE_DIR="$T/image-variant" bash "$here/lab-preview.sh" c05 e-final >/dev/null 2>&1; drift=$?
nd=$(jq -r .digest "$T/o2/c05/e-final/card.json"); grep -q 'image_digest.*RED' "$T/o2/c05/e-final/card.md"; row=$?
echo "F1 unchanged-digest exit=$same (want 3 SKIPPED, SKIP_GRADE=1); changed-line exit=$drift (want 1); digest differs=$([ "$nd" != "$base" ] && echo yes || echo no); card row RED=$([ $row -eq 0 ] && echo yes || echo no)"
f1=1; [ "$same" -eq 3 ] && [ "$drift" -eq 1 ] && [ "$nd" != "$base" ] && [ "$row" -eq 0 ] && f1=0
mkdir -p "$T/sol"; grep -v 'push_cast; rw \[Int.add_mul' "$lab/solution/Mean.lean" > "$T/sol/Mean.lean"; chmod -R a+rX "$T"
cmp -s "$T/sol/Mean.lean" "$lab/solution/Mean.lean" && { echo "F2 NOT MEASURED: step line not found"; exit 2; }
PORT=18095 OUT="$T/o3" SOLUTION_DIR="$(basename "$T")/sol" bash "$here/lab-preview.sh" c05 e-final >/dev/null 2>&1; sol=$?
sv=$(grep '^| solution' "$T/o3/c05/e-final/card.md" | awk -F'|' '{print $6}' | tr -d ' ')
echo "F2 solution-with-step-removed: preview exit=$sol (want 1), solution row verdict=$sv (want FAIL)"
f2=1; [ "$sol" -eq 1 ] && [ "$sv" = FAIL ] && f2=0
[ $f1 -eq 0 ] && [ $f2 -eq 0 ] && { echo "falsify-lab-preview: GREEN"; exit 0; }
echo "falsify-lab-preview: RED"; exit 1
