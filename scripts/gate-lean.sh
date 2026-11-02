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
# The ols-demo exe ends with its proved verdict: a wrong residual sum must fail the gate, not only the p2 test.
out=$(lake exe ols-demo ../.. 2>&1) || { echo "FAIL ols-demo: $out"; exit 1; }
last=$(echo "$out" | tail -n 1 | sed 's/\x1b\[[0-9;]*m//g')
[ "$last" = "residuals sum to 0: proved (theorem residuals_sum)" ] || { echo "FAIL ols-demo last line: $last"; exit 1; }

# Every demo that once printed nothing must end in its contract line (ads#132); the checker must refuse empty stdout.
scripts/falsify-rerun-lean-demos.sh >/dev/null || { echo "FAIL rerun-lean-demos falsifier"; scripts/falsify-rerun-lean-demos.sh; exit 1; }
out=$(scripts/rerun-lean-demos.sh 2 .lake/build/bin $(cat scripts/contract-demos.txt) 2>&1) || { echo "FAIL contract demos: $out"; exit 1; }

# Example files lake does not build must still elaborate; the planted fault must still be refused.
for f in AgenticDS/Examples/M2V04.lean AgenticDS/Examples/M2V05.lean AgenticDS/Examples/M2V09.lean; do
  out=$(lake env lean "$f" 2>&1) || { echo "FAIL $f: $out"; exit 1; }
  # Each also writes its plot from real data: the contract line must print.
  echo "$out" | grep -q "contract: plot_scatter_bounded OK" || { echo "FAIL $f printed no plot contract: $out"; exit 1; }
done
if lake env lean AgenticDSTest/PlantedWrongSlope.lean >/dev/null 2>&1; then echo "FAIL PlantedWrongSlope.lean no longer fails"; exit 1; fi
# savePlot must surface a failing ImageMagick convert (stub convert: answers -version, then fails).
cstub=$(mktemp -d)
printf '#!/bin/sh\n[ "$1" = "-version" ] && exit 0\necho stub-convert-failed >&2\nexit 1\n' > "$cstub/convert"; chmod +x "$cstub/convert"
if out=$(PATH="$cstub:$PATH" lake exe ols-demo ../.. 2>&1); then rm -rf "${cstub:?}" plot.svg; echo "FAIL ols-demo ignored a failing convert: $out"; exit 1; fi
rm -rf "${cstub:?}" plot.svg
echo "$out" | grep -q "convert failed" || { echo "FAIL ols-demo failed for another reason than convert: $out"; exit 1; }
# Every function and every refusal path has a test (Lean has no line-coverage tool); the falsifier proves the check can fail.
bash ../../scripts/falsify-lean-fn-coverage.sh >/dev/null || { echo "FAIL lean fn-coverage falsifier"; bash ../../scripts/falsify-lean-fn-coverage.sh; exit 1; }
bash ../../scripts/check-lean-fn-coverage.sh || { echo "FAIL lean fn coverage"; exit 1; }
bash ../../scripts/gate-lean-anscombe.sh || exit 1
rcp=$(mktemp); trap 'rm -f "${rcp:?}"' EXIT
../../labs/c05-final/tests/lab-verify.sh "$rcp" || { echo "FAIL lab c05-final"; exit 1; }
echo "lean OK"
