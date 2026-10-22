#!/usr/bin/env bash
# Lean gate: warnings-as-errors build, no sorry/native_decide/SATD markers, axioms within the allowed set, golden parity test.
# pmat reads no Lean sources (measured 10-22, pmat 3.42.0: planted TODO file stays green), so it is not a Lean gate.
set -uo pipefail
cd "$(dirname "$0")/../lean/AgenticDS"
export PATH="$HOME/.elan/bin:$PATH"
lake build >/dev/null 2>&1 || { echo "FAIL lean build"; lake build 2>&1 | grep -v "module system" | tail -20; exit 1; }
if grep -rn --include=*.lean -E "\b(sorry|admit)\b|native_decide|TODO|FIXME|HACK|XXX" AgenticDS.lean AgenticDS AgenticDSTest scripts; then echo "FAIL sorry/admit/native_decide/SATD"; exit 1; fi
want=$(grep -c '^#print axioms' scripts/Axioms.lean)
[ "$want" -ge 1 ] || { echo "FAIL Axioms.lean lists no theorem"; exit 1; }
ax=$(lake env lean -DwarningAsError=true scripts/Axioms.lean 2>&1) || { echo "FAIL Axioms.lean did not elaborate: $ax"; exit 1; }
[ "$(echo "$ax" | grep -c 'depends on axioms')" = "$want" ] || { echo "FAIL axioms: expected $want theorem lines"; echo "$ax"; exit 1; }
bad=$(echo "$ax" | grep "depends on axioms" | grep -vE "depends on axioms: \[(propext|Classical.choice|Quot.sound)(, (propext|Classical.choice|Quot.sound))*\]$")
[ -z "$bad" ] || { echo "FAIL axioms: $bad"; exit 1; }
for t in AgenticDSTest/P*.lean; do
  id="ads-lean-p$(basename "$t" .lean | tr -d P)-v1"
  out=$(lake env lean -DwarningAsError=true --run "$t" ../.. 2>&1) || { echo "FAIL golden parity $t: $out"; exit 1; }
  echo "$out" | grep -q "contract: $id OK$" || { echo "FAIL golden parity $t: $out"; exit 1; }
done
echo "lean OK"
