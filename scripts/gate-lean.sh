#!/usr/bin/env bash
# Lean gate: warnings-as-errors build, no sorry/native_decide/SATD markers, axioms within the allowed set, golden parity test.
# pmat reads no Lean sources (measured 10-22, pmat 3.42.0: planted TODO file stays green), so it is not a Lean gate.
set -uo pipefail
cd "$(dirname "$0")/../lean/AgenticDS" || exit 1
export PATH="$HOME/.elan/bin:$PATH"
# The tests are lean_exe targets in lakefile.toml (same sources, same leanOptions), compiled by `lake build` above; the gate runs the binaries,
# so no test re-elaborates Mathlib at run time (demo-v2). A test that fails to compile fails `lake build`; one that fails at run time fails here.
BIN=.lake/build/bin
lake build >/dev/null 2>&1 || { echo "FAIL lean build"; lake build 2>&1 | grep -v "module system" | tail -20; exit 1; }
if grep -rn --include=*.lean --include=*.lean.planted -E "\b(sorry|admit)\b|native_decide|TODO|FIXME|HACK|XXX" AgenticDS.lean AgenticDS AgenticDSTest scripts; then echo "FAIL sorry/admit/native_decide/SATD"; exit 1; fi
# An example or test that imports Mathlib again at run time held 15 GB per import and was killed on the runner (SIGTERM); read the kernel at elaboration instead.
if grep -rn --include=*.lean -E "\\b(importModules|withImportModules)\\b" AgenticDS AgenticDSTest; then echo "FAIL run-time importModules (memory)"; exit 1; fi
for f in scripts/Axioms.lean scripts/AxiomsM*.lean; do
  [ -e "$f" ] || continue
  want=$(grep -c '^#print axioms' "$f")
  [ "$want" -ge 1 ] || { echo "FAIL $f lists no theorem"; exit 1; }
  ax=$(lake env lean -DwarningAsError=true "$f" 2>&1) || { echo "FAIL $f did not elaborate: $ax"; exit 1; }
  [ "$(echo "$ax" | grep -c 'depends on axioms')" = "$want" ] || { echo "FAIL $f: expected $want theorem lines"; echo "$ax"; exit 1; }
  bad=$(echo "$ax" | grep "depends on axioms" | grep -vE "depends on axioms: \[(propext|Classical.choice|Quot.sound)(, (propext|Classical.choice|Quot.sound))*\]$")
  [ -z "$bad" ] || { echo "FAIL $f: $bad"; exit 1; }
done
out=$($BIN/agentic-ds-test ../.. 2>&1) || { echo "FAIL golden parity: $out"; exit 1; }
echo "$out" | grep -q "contract: ads-lean-p1-v1 OK$" || { echo "FAIL golden parity: $out"; exit 1; }
out=$($BIN/ols-test ../.. 2>&1) || { echo "FAIL ols test: $out"; exit 1; }
echo "$out" | grep -q "contract: ads-lean-p2-v1 OK$" || { echo "FAIL ols test: $out"; exit 1; }
# The ols-demo exe ends with its proved verdict: a wrong residual sum must fail the gate, not only the p2 test.
out=$($BIN/ols-demo ../.. 2>&1) || { echo "FAIL ols-demo: $out"; exit 1; }
last=$(echo "$out" | tail -n 1 | sed 's/\x1b\[[0-9;]*m//g')
[ "$last" = "residuals sum to 0: proved (theorem residuals_sum)" ] || { echo "FAIL ols-demo last line: $last"; exit 1; }

# One test per module of examples, each ending in its own contract line.
for t in AgenticDSTest/ExamplesM*.lean; do
  [ -e "$t" ] || continue
  m=$(basename "$t" .lean); m=${m#ExamplesM}
  out=$("$BIN/examples-test-m$m" ../.. 2>&1) || { echo "FAIL $t: $out"; exit 1; }
  echo "$out" | grep -q "contract: ads-lean-examples-m$m-v1 OK$" || { echo "FAIL $t: $out"; exit 1; }
done
# Every demo that once printed nothing must end in its contract line (ads#132); the checker must refuse empty stdout.
scripts/falsify-rerun-lean-demos.sh >/dev/null || { echo "FAIL rerun-lean-demos falsifier"; scripts/falsify-rerun-lean-demos.sh; exit 1; }
out=$(scripts/rerun-lean-demos.sh 2 .lake/build/bin $(cat scripts/contract-demos.txt) 2>&1) || { echo "FAIL contract demos: $out"; exit 1; }

# Example files lake does not build must still elaborate; the planted fault must still be refused.
for f in AgenticDS/Examples/M2V04.lean AgenticDS/Examples/M2V05.lean AgenticDS/Examples/M2V09.lean; do
  out=$(lake env lean "$f" 2>&1) || { echo "FAIL $f: $out"; exit 1; }
  # Each also writes its plot from real data: the contract line must print.
  echo "$out" | grep -q "contract: plot_scatter_bounded OK" || { echo "FAIL $f printed no plot contract: $out"; exit 1; }
done
# The planted fault is stored as .lean.planted (T12p measures every tracked .lean and this one must never elaborate): copy it in, require the
# guard to REFUSE it (exit 1 and the guard message), remove the copy.
cp AgenticDSTest/PlantedWrongSlope.lean.planted AgenticDSTest/PlantedWrongSlope.lean
out=$(lake env lean AgenticDSTest/PlantedWrongSlope.lean 2>&1); rc=$?; rm -f AgenticDSTest/PlantedWrongSlope.lean
if [ "$rc" -eq 0 ]; then echo "FAIL PlantedWrongSlope no longer fails"; exit 1; fi
echo "$out" | grep -q "olsSlope planted" || { echo "FAIL PlantedWrongSlope failed for another reason: $out"; exit 1; }
# The built binaries that the course plates type (GH-2159): the planted slope must be refused by `planted-slope` (exit 1 + message), the true slope must print
# 5/2 and its contract line, and the module-2 test must end on its contract line.
out=$(.lake/build/bin/planted-slope 2>&1); rc=$?
[ "$rc" -eq 1 ] || { echo "FAIL planted-slope exit $rc: $out"; exit 1; }
case $out in *"olsSlope planted == 2 did not evaluate to \`true\`"*) ;; *) echo "FAIL planted-slope message: $out"; exit 1;; esac
out=$(.lake/build/bin/m2v09-slope 2>&1) || { echo "FAIL m2v09-slope: $out"; exit 1; }
case $out in "5/2"$'\n'"contract: ads-lean-m2v09-slope-v1 OK") ;; *) echo "FAIL m2v09-slope output: $out"; exit 1;; esac
out=$(.lake/build/bin/examples-m2-test ../.. 2>&1) || { echo "FAIL examples-m2-test: $out"; exit 1; }
case $out in *"contract: ads-lean-examples-m2-v1 OK") ;; *) echo "FAIL examples-m2-test output: $out"; exit 1;; esac
# The svg contract must fire: 14 rows overflow the picture, an empty chart is refused.
for p in tall empty; do
  if out=$($BIN/planted-svg-overflow $p 2>&1); then echo "FAIL PlantedSvgOverflow $p no longer fails: $out"; exit 1; fi
  echo "$out" | grep -q "plot_svg_bounded violated" || { echo "FAIL PlantedSvgOverflow $p failed for another reason: $out"; exit 1; }
done
# The scatter contract must fire on an empty plot and on a NaN point.
for p in empty nan; do
  if out=$($BIN/planted-scatter $p 2>&1); then echo "FAIL PlantedScatter $p no longer fails: $out"; exit 1; fi
  echo "$out" | grep -q "plot_scatter_bounded violated" || { echo "FAIL PlantedScatter $p failed for another reason: $out"; exit 1; }
done
if [ -e AgenticDSTest/P4.lean ]; then
  out=$($BIN/p4-test ../.. 2>&1) || { echo "FAIL p4 test: $out"; exit 1; }
  echo "$out" | grep -q "contract: ads-lean-p4-v1 OK$" || { echo "FAIL p4 test: $out"; exit 1; }
fi
bash ../../scripts/gate-lean-anscombe.sh || exit 1
rcp=$(mktemp); trap 'rm -f "${rcp:?}"' EXIT
../../labs/c05-final/tests/lab-verify.sh "$rcp" || { echo "FAIL lab c05-final"; exit 1; }
echo "lean OK"
