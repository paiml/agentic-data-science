#!/usr/bin/env bash
# The axiom scan must refuse a planted axiom and pass a clean tree.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd); d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
printf 'theorem t : True := trivial\n' > "$d/Clean.lean"
"$here/scan-axiom-decls.sh" "$d" >/dev/null || { echo "FAIL clean tree refused"; exit 1; }
for decl in 'axiom bad : False' 'private axiom bad : False' '@[simp] axiom bad : False'; do
  printf '%s\n' "$decl" > "$d/Planted.lean"
  "$here/scan-axiom-decls.sh" "$d" >/dev/null && { echo "FAIL planted not refused: $decl"; exit 1; }
done
echo "falsify-axiom-scan OK"
