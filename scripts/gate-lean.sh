#!/usr/bin/env bash
# Lean gate: warnings-as-errors build, no sorry/native_decide/SATD markers, axioms within the allowed set, golden parity test.
# pmat reads no Lean sources (measured 10-22, pmat 3.42.0: planted TODO file stays green), so it is not a Lean gate.
set -uo pipefail
cd "$(dirname "$0")/../lean/AgenticDS"
export PATH="$HOME/.elan/bin:$PATH"
lake build 2>&1 | grep -v "designed for use with the module system" | grep -E "^(error|✖)" && { echo "FAIL lean build"; exit 1; }
lake build >/dev/null 2>&1 || { echo "FAIL lean build"; exit 1; }
if grep -rn --include=*.lean -E "\bsorry\b|native_decide|TODO|FIXME|HACK|XXX" AgenticDS AgenticDSTest scripts; then echo "FAIL sorry/native_decide"; exit 1; fi
ax=$(lake env lean scripts/Axioms.lean 2>&1)
echo "$ax" | grep -q "depends on axioms" || { echo "FAIL axioms not measured"; exit 1; }
bad=$(echo "$ax" | grep "depends on axioms" | grep -vE "depends on axioms: \[(propext|Classical.choice|Quot.sound)(, (propext|Classical.choice|Quot.sound))*\]$")
[ -z "$bad" ] || { echo "FAIL axioms: $bad"; exit 1; }
lake env lean --run AgenticDSTest/Main.lean ../.. | grep -q "OK$" || { echo "FAIL golden parity"; exit 1; }
echo "lean OK"
