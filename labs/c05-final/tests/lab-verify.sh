#!/usr/bin/env bash
# lab-verify.sh : the lab-audit-fix gate. The starter must FAIL (non-zero, named failing tasks); the solution must PASS (zero).
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd); R=${1:-$here/../receipt.txt}
s=$("$here/lab-run.sh" "$here/../starter" 2>&1); sc=$?; z=$("$here/lab-run.sh" "$here/../solution" 2>&1); zc=$?
{ echo "starter_exit=$sc"; echo "$s" | grep '^FAIL' | sed 's/^/starter_/'; echo "solution_exit=$zc"; echo "$z" | grep '^PASS' | sed 's/^/solution_/'
  echo "commit=$(git -C "$here" rev-parse HEAD)"; } > "$R"
cat "$R"
[ "$sc" -eq 1 ] || { echo "lab-verify: RED starter exit $sc, want 1"; exit 1; }
[ "$zc" -eq 0 ] || { echo "lab-verify: RED solution exit $zc, want 0"; exit 1; }
echo "$s" | grep -q '^FAIL' || { echo "lab-verify: RED starter failed with no named task"; exit 1; }
echo "lab-verify: GREEN"
