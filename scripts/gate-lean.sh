#!/usr/bin/env bash
# Lean gate: warnings-as-errors build, no sorry/native_decide/SATD markers, axioms within the allowed set, golden parity test.
# pmat reads no Lean sources (measured 10-22, pmat 3.42.0: planted TODO file stays green), so it is not a Lean gate.
set -uo pipefail
cd "$(dirname "$0")/../lean/AgenticDS" || exit 1
export PATH="$HOME/.elan/bin:$PATH"
# The tests are lean_exe targets in lakefile.toml (same sources, same leanOptions), compiled by `lake build` above; the gate runs the binaries,
# so no test re-elaborates Mathlib at run time (demo-v2). A test that fails to compile fails `lake build`; one that fails at run time fails here.
# Progress: one "[n/N] stage" line before each stage, plus an elapsed line every 2 s while it runs, so a recording never shows a blank terminal (ads c05 m1-09).
NSTAGES=17; SN=0; T0=$SECONDS; HB=""
hb_stop() { if [ -n "$HB" ]; then kill "$HB" 2>/dev/null; wait "$HB" 2>/dev/null; fi; HB=""; return 0; }
HBS=${GATE_LEAN_HEARTBEAT_S:-2}  # 0 = no elapsed lines, so a term-<id> demo prints the same bytes on every run
stage() { hb_stop; SN=$((SN+1)); echo "[$SN/$NSTAGES] $1"; [ "$HBS" = 0 ] && return 0; ( while sleep 2 >/dev/null 2>&1; do echo "  ... $((SECONDS-T0)) s"; done ) & HB=$!; }
trap hb_stop EXIT
BIN=.lake/build/bin
stage "lake build (warnings are errors)"
lake build >/dev/null 2>&1 || { echo "FAIL lean build"; lake build 2>&1 | grep -v "module system" | tail -20; exit 1; }
stage "marker scan: sorry, admit, native_decide, TODO"
if grep -rn --include=*.lean --include=*.lean.planted -E "\b(sorry|admit)\b|native_decide|TODO|FIXME|HACK|XXX" AgenticDS.lean AgenticDS AgenticDSTest scripts; then echo "FAIL sorry/admit/native_decide/SATD"; exit 1; fi
stage "axiom scan + run-time importModules scan"
# A user-declared axiom is banned even when no #print axioms line lists it (c05 2.3.0); the falsifier plants one and must see it refused.
scripts/falsify-lean-axiom-scan.sh >/dev/null || { echo "FAIL axiom-scan falsifier"; scripts/falsify-lean-axiom-scan.sh; exit 1; }
if ! scripts/lean-axiom-scan.sh AgenticDS.lean AgenticDS AgenticDSTest scripts; then echo "FAIL user-declared axiom"; exit 1; fi
# An example or test that imports Mathlib again at run time held 15 GB per import and was killed on the runner (SIGTERM); read the kernel at elaboration instead.
if grep -rn --include=*.lean -E "\\b(importModules|withImportModules)\\b" AgenticDS AgenticDSTest; then echo "FAIL run-time importModules (memory)"; exit 1; fi
stage "axioms: every theorem within the allowed set"
for f in scripts/Axioms.lean scripts/AxiomsM*.lean; do
  [ -e "$f" ] || continue
  want=$(grep -c '^#print axioms' "$f")
  [ "$want" -ge 1 ] || { echo "FAIL $f lists no theorem"; exit 1; }
  ax=$(lake env lean -DwarningAsError=true "$f" 2>&1) || { echo "FAIL $f did not elaborate: $ax"; exit 1; }
  [ "$(echo "$ax" | grep -c 'depends on axioms')" = "$want" ] || { echo "FAIL $f: expected $want theorem lines"; echo "$ax"; exit 1; }
  bad=$(echo "$ax" | grep "depends on axioms" | grep -vE "depends on axioms: \[(propext|Classical.choice|Quot.sound)(, (propext|Classical.choice|Quot.sound))*\]$")
  [ -z "$bad" ] || { echo "FAIL $f: $bad"; exit 1; }
done
stage "run-list tests: every Lean test run"
# Every Lean test run in scripts/run-list.tsv (the coverage check takes its entry points from the same list).
while IFS=$'\t' read -r id mode file arg needle; do
  case "$id" in ''|'#'*) continue;; esac
  case "$mode" in
    ok)
      out=$(lake env lean "${LEANOPTS[@]}" --run "$file" "$arg" 2>&1) || { echo "FAIL $id: $out"; exit 1; }
      echo "$out" | grep -q "$needle\$" || { echo "FAIL $id: $out"; exit 1; } ;;
    refuse)
      if out=$(lake env lean "${LEANOPTS[@]}" --run "$file" "$arg" 2>&1); then echo "FAIL $id no longer fails: $out"; exit 1; fi
      echo "$out" | grep -qF -- "$needle" || { echo "FAIL $id failed for another reason: $out"; exit 1; } ;;
    stub) ;;
    *) echo "FAIL run-list: unknown mode '$mode' for $id"; exit 1;;
  esac
done < scripts/run-list.tsv
stage "golden parity test"
out=$($BIN/agentic-ds-test ../.. 2>&1) || { echo "FAIL golden parity: $out"; exit 1; }
echo "$out" | grep -q "contract: ads-lean-p1-v1 OK$" || { echo "FAIL golden parity: $out"; exit 1; }
stage "OLS test"
out=$($BIN/ols-test ../.. 2>&1) || { echo "FAIL ols test: $out"; exit 1; }
echo "$out" | grep -q "contract: ads-lean-p2-v1 OK$" || { echo "FAIL ols test: $out"; exit 1; }
stage "ols-demo ends in its proved verdict"
# The ols-demo exe ends with its proved verdict: a wrong residual sum must fail the gate, not only the p2 test.
out=$($BIN/ols-demo ../.. 2>&1) || { echo "FAIL ols-demo: $out"; exit 1; }
last=$(echo "$out" | tail -n 1 | sed 's/\x1b\[[0-9;]*m//g')
[ "$last" = "residuals sum to 0: proved (theorem residuals_sum)" ] || { echo "FAIL ols-demo last line: $last"; exit 1; }

stage "example tests, one per module"
# One test per module of examples, each ending in its own contract line.
for t in AgenticDSTest/ExamplesM*.lean; do
  [ -e "$t" ] || continue
  m=$(basename "$t" .lean); m=${m#ExamplesM}
  # module 2's binary is examples-m2-test (the name the course plates type, GH-2159); lake refuses two exes on one root.
  b=examples-test-m$m; [ "$m" = 2 ] && b=examples-m2-test
  out=$("$BIN/$b" ../.. 2>&1) || { echo "FAIL $t: $out"; exit 1; }
  echo "$out" | grep -q "contract: ads-lean-examples-m$m-v1 OK$" || { echo "FAIL $t: $out"; exit 1; }
done
stage "contract demos print their contract line"
# Every demo that once printed nothing must end in its contract line (ads#132); the checker must refuse empty stdout.
scripts/falsify-rerun-lean-demos.sh >/dev/null || { echo "FAIL rerun-lean-demos falsifier"; scripts/falsify-rerun-lean-demos.sh; exit 1; }
scripts/falsify-emit-demo-json.sh >/dev/null || { echo "FAIL emit-demo-json falsifier"; scripts/falsify-emit-demo-json.sh; exit 1; }
out=$(scripts/rerun-lean-demos.sh 2 .lake/build/bin $(cat scripts/contract-demos.txt) 2>&1) || { echo "FAIL contract demos: $out"; exit 1; }

stage "example files lake does not build"
# Example files lake does not build must still elaborate; the planted fault must still be refused.
for f in AgenticDS/Examples/M2V04.lean AgenticDS/Examples/M2V05.lean AgenticDS/Examples/M2V09.lean; do
  out=$(lake env lean "$f" 2>&1) || { echo "FAIL $f: $out"; exit 1; }
  # Each also writes its plot from real data: the contract line must print.
  echo "$out" | grep -q "contract: plot_scatter_bounded OK" || { echo "FAIL $f printed no plot contract: $out"; exit 1; }
done
# savePlot must surface a failing ImageMagick convert (stub convert: answers -version, then fails).
cstub=$(mktemp -d)
printf '#!/bin/sh\n[ "$1" = "-version" ] && exit 0\necho stub-convert-failed >&2\nexit 1\n' > "$cstub/convert"; chmod +x "$cstub/convert"
if out=$(PATH="$cstub:$PATH" lake exe ols-demo ../.. 2>&1); then rm -rf "${cstub:?}" plot.svg; echo "FAIL ols-demo ignored a failing convert: $out"; exit 1; fi
rm -rf "${cstub:?}" plot.svg
echo "$out" | grep -q "convert failed" || { echo "FAIL ols-demo failed for another reason than convert: $out"; exit 1; }
stage "lean fn coverage"
# Every function and every refusal path has a test (Lean has no line-coverage tool); the falsifier proves the check can fail.
bash ../../scripts/falsify-lean-fn-coverage.sh >/dev/null || { echo "FAIL lean fn-coverage falsifier"; bash ../../scripts/falsify-lean-fn-coverage.sh; exit 1; }
bash ../../scripts/check-lean-fn-coverage.sh || { echo "FAIL lean fn coverage"; exit 1; }
stage "planted wrong slope refused"
# The planted fault is stored as .lean.planted (T12p measures every tracked .lean and this one must never elaborate): copy it in, require the
# guard to REFUSE it (exit 1 and the guard message), remove the copy.
cp AgenticDSTest/PlantedWrongSlope.lean.planted AgenticDSTest/PlantedWrongSlope.lean
out=$(lake env lean AgenticDSTest/PlantedWrongSlope.lean 2>&1); rc=$?; rm -f AgenticDSTest/PlantedWrongSlope.lean
if [ "$rc" -eq 0 ]; then echo "FAIL PlantedWrongSlope no longer fails"; exit 1; fi
echo "$out" | grep -q "olsSlope planted" || { echo "FAIL PlantedWrongSlope failed for another reason: $out"; exit 1; }
stage "built binaries the plates type"
# The built binaries that the course plates type (GH-2159): the planted slope must be refused by `planted-slope` (exit 1 + message), the true slope must print
# 5/2 and its contract line, and the module-2 test must end on its contract line.
out=$(.lake/build/bin/planted-slope 2>&1); rc=$?
[ "$rc" -eq 1 ] || { echo "FAIL planted-slope exit $rc: $out"; exit 1; }
case $out in *"olsSlope planted == 2 did not evaluate to \`true\`"*) ;; *) echo "FAIL planted-slope message: $out"; exit 1;; esac
out=$(.lake/build/bin/m2v09-slope 2>&1) || { echo "FAIL m2v09-slope: $out"; exit 1; }
case $out in "5/2"$'\n'"contract: ads-lean-m2v09-slope-v1 OK") ;; *) echo "FAIL m2v09-slope output: $out"; exit 1;; esac
out=$(.lake/build/bin/examples-m2-test ../.. 2>&1) || { echo "FAIL examples-m2-test: $out"; exit 1; }
case $out in *"contract: ads-lean-examples-m2-v1 OK") ;; *) echo "FAIL examples-m2-test output: $out"; exit 1;; esac
stage "svg and scatter contracts fire"
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
# The source-row contract must fire on swapped axes, a wrong row, a missing and an extra row.
for p in swap row missing extra; do
  if out=$(lake env lean "${LEANOPTS[@]}" --run AgenticDSTest/PlantedScatterSource.lean $p 2>&1); then echo "FAIL PlantedScatterSource $p no longer fails: $out"; exit 1; fi
  echo "$out" | grep -q "plot_scatter_source violated" || { echo "FAIL PlantedScatterSource $p failed for another reason: $out"; exit 1; }
done
# One planted run per id (v05, v08, v09) must be refused by the m3 scatter pins.
scripts/falsify-m3-scatter.sh >/dev/null || { echo "FAIL m3 scatter falsifier"; scripts/falsify-m3-scatter.sh; exit 1; }
if [ -e AgenticDSTest/P4.lean ]; then
  out=$($BIN/p4-test ../.. 2>&1) || { echo "FAIL p4 test: $out"; exit 1; }
  echo "$out" | grep -q "contract: ads-lean-p4-v1 OK$" || { echo "FAIL p4 test: $out"; exit 1; }
fi
stage "anscombe gate"
bash ../../scripts/gate-lean-anscombe.sh || exit 1
stage "lab c05-final"
rcp=$(mktemp); trap 'hb_stop; rm -f "${rcp:?}"' EXIT
../../labs/c05-final/tests/lab-verify.sh "$rcp" || { echo "FAIL lab c05-final"; exit 1; }
hb_stop; echo "lean OK"
