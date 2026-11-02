#!/usr/bin/env bash
# Falsifier for the m3 penguin scatter pins in AgenticDSTest/ExamplesM3.lean: for each of v05, v08, v09 one run
# of the test with that id's pinned n changed must FAIL and name the id; the unmodified test must pass. Run from lean/AgenticDS.
set -uo pipefail
export PATH="$HOME/.elan/bin:$PATH"
T=$(mktemp -d); trap 'rm -rf "${T:?}"' EXIT
src=AgenticDSTest/ExamplesM3.lean; fail=0
run() { lake env lean --run "$1" ../.. 2>&1; }
out=$(run "$src") || { echo "FAIL arm good: $out"; exit 1; }
echo "$out" | grep -q 'contract: ads-lean-examples-m3-v1 OK$' || { echo "FAIL arm good: no contract line"; exit 1; }
echo "arm good ok"
for id in v05 v08 v09; do
  col=$(awk -v id="\"$id\"" '$0 ~ "\\(" id ", \\[" {print $0; exit}' "$src" | sed -E 's/.*\["([a-z_]+ vs [a-z_]+): n = 86.*/\1/')
  [ -n "$col" ] || { echo "FAIL arm $id: no pinned line"; fail=1; continue; }
  sed "s/\"$col: n = 86\"/\"$col: n = 87\"/" "$src" > "$T/M3_$id.lean"
  cmp -s "$src" "$T/M3_$id.lean" && { echo "FAIL arm $id: plant did not change the file"; fail=1; continue; }
  if o=$(run "$T/M3_$id.lean"); then echo "FAIL arm $id: planted n=87 not refused"; fail=1
  elif echo "$o" | grep -q "FAIL $id lacks"; then echo "arm $id ok"
  else echo "FAIL arm $id: refused for another reason: $o"; fail=1; fi
done
[ "$fail" -eq 0 ] && echo "falsifier OK (4 arms)"
exit "$fail"
