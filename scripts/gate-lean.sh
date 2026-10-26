#!/usr/bin/env bash
# Lean gate: warnings-as-errors build, no sorry/native_decide/SATD markers, axioms within the allowed set, golden parity test.
# pmat reads no Lean sources (measured 10-22, pmat 3.42.0: planted TODO file stays green), so it is not a Lean gate.
set -uo pipefail
cd "$(dirname "$0")/../lean/AgenticDS" || exit 1
export PATH="$HOME/.elan/bin:$PATH"
# Same linters as lakefile.toml leanOptions, for the test file lake does not build (Axioms.lean is #print-only: hashCommand would always fire).
LEANOPTS=(-DwarningAsError=true -Dweak.linter.mathlibStandardSet=true -Dweak.linter.style.longLine.maxLineLength=68 "-Dweak.linter.style.header.license=Released under MIT license as described in the file LICENSE.")
lake build >/dev/null 2>&1 || { echo "FAIL lean build"; lake build 2>&1 | grep -v "module system" | tail -20; exit 1; }
if grep -rn --include=*.lean -E "\b(sorry|admit)\b|native_decide|TODO|FIXME|HACK|XXX" AgenticDS.lean AgenticDS AgenticDSTest scripts; then echo "FAIL sorry/admit/native_decide/SATD"; exit 1; fi
for f in scripts/Axioms.lean scripts/AxiomsM*.lean; do
  [ -e "$f" ] || continue
  want=$(grep -c '^#print axioms' "$f")
  [ "$want" -ge 1 ] || { echo "FAIL $f lists no theorem"; exit 1; }
  ax=$(lake env lean -DwarningAsError=true "$f" 2>&1) || { echo "FAIL $f did not elaborate: $ax"; exit 1; }
  [ "$(echo "$ax" | grep -c 'depends on axioms')" = "$want" ] || { echo "FAIL $f: expected $want theorem lines"; echo "$ax"; exit 1; }
  bad=$(echo "$ax" | grep "depends on axioms" | grep -vE "depends on axioms: \[(propext|Classical.choice|Quot.sound)(, (propext|Classical.choice|Quot.sound))*\]$")
  [ -z "$bad" ] || { echo "FAIL $f: $bad"; exit 1; }
done
out=$(lake env lean "${LEANOPTS[@]}" --run AgenticDSTest/Main.lean ../.. 2>&1) || { echo "FAIL golden parity: $out"; exit 1; }
echo "$out" | grep -q "contract: ads-lean-p1-v1 OK$" || { echo "FAIL golden parity: $out"; exit 1; }
out=$(lake env lean "${LEANOPTS[@]}" --run AgenticDSTest/OlsTest.lean ../.. 2>&1) || { echo "FAIL ols test: $out"; exit 1; }
echo "$out" | grep -q "contract: ads-lean-p2-v1 OK$" || { echo "FAIL ols test: $out"; exit 1; }
# One test per module of examples, each ending in its own contract line.
for t in AgenticDSTest/ExamplesM*.lean; do
  [ -e "$t" ] || continue
  m=$(basename "$t" .lean); m=${m#ExamplesM}
  out=$(lake env lean "${LEANOPTS[@]}" --run "$t" ../.. 2>&1) || { echo "FAIL $t: $out"; exit 1; }
  echo "$out" | grep -q "contract: ads-lean-examples-m$m-v1 OK$" || { echo "FAIL $t: $out"; exit 1; }
done
# Example files lake does not build must still elaborate; the planted fault must still be refused.
for f in AgenticDS/Examples/M2V04.lean AgenticDS/Examples/M2V05.lean AgenticDS/Examples/M2V09.lean; do
  out=$(lake env lean "$f" 2>&1) || { echo "FAIL $f: $out"; exit 1; }
done
if lake env lean AgenticDSTest/PlantedWrongSlope.lean >/dev/null 2>&1; then echo "FAIL PlantedWrongSlope.lean no longer fails"; exit 1; fi
if [ -e AgenticDSTest/P4.lean ]; then
  out=$(lake env lean "${LEANOPTS[@]}" --run AgenticDSTest/P4.lean ../.. 2>&1) || { echo "FAIL p4 test: $out"; exit 1; }
  echo "$out" | grep -q "contract: ads-lean-p4-v1 OK$" || { echo "FAIL p4 test: $out"; exit 1; }
fi
echo "lean OK"
