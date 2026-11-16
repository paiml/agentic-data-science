#!/usr/bin/env bash
# lab-run.sh LABDIR : grade LABDIR/Lab.lean. Exit 0 = every task proved, 1 = a task failed (each named), 2 = could not measure.
# A task passes only if it elaborates with warnings as errors AND `#print axioms` lists no sorryAx and nothing outside
# {propext, Classical.choice, Quot.sound}.
set -uo pipefail
D=${1:?lab dir (starter or solution)}; D=$(cd "$D" && pwd)
H=$(cd "$(dirname "$0")/../../../lean/AgenticDS" && pwd); export PATH="$HOME/.elan/bin:$PATH"
[ -s "$D/Lab.lean" ] || { echo "NOT MEASURED: $D/Lab.lean missing"; exit 2; }
TASKS=$(sed -n 's/^theorem \(lab_[A-Za-z0-9_]*\).*/\1/p' "$D/Lab.lean")
[ -n "$TASKS" ] || { echo "NOT MEASURED: no lab_ theorems (a zero-test suite never passes)"; exit 2; }
T=$(mktemp -d); trap 'rm -rf "${T:?}"' EXIT
cp "$D/Lab.lean" "$T/Lab.lean"; for t in $TASKS; do echo "#print axioms $t" >> "$T/Lab.lean"; done
out=$(cd "$H" && lake env lean -DwarningAsError=false "$T/Lab.lean" 2>&1); rc=$?
echo "$out" | grep -E "error" | head -5
fail=0
for t in $TASKS; do
  line=$(echo "$out" | grep -E "^'$t' depends on axioms|^'$t' does not depend on any axioms")
  if [ -z "$line" ]; then echo "FAIL $t (does not elaborate)"; fail=$((fail+1)); continue; fi
  if echo "$line" | grep -qE "sorryAx"; then echo "FAIL $t (sorry)"; fail=$((fail+1)); continue; fi
  if echo "$line" | grep -E "depends on axioms" | grep -vE "\[(propext|Classical.choice|Quot.sound)(, (propext|Classical.choice|Quot.sound))*\]$" >/dev/null; then echo "FAIL $t (axiom outside the allowed set)"; fail=$((fail+1)); continue; fi
  echo "PASS $t"
done
n=$(echo $TASKS | wc -w)
[ "$rc" -eq 0 ] || [ "$fail" -gt 0 ] || { echo "FAIL lean exit $rc"; fail=1; }
echo "lab: $((n-fail))/$n tasks pass"; [ "$fail" -eq 0 ] && exit 0 || exit 1
