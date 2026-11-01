#!/usr/bin/env bash
# Runs the lab's one test suite on the starter and on the solution and prints both exit codes.
# Proof = starter exits non-zero (and names failing tests), solution exits 0, test files byte-identical.
# Optional MUTANTS=1 also runs two broken solutions (must both fail). Needs Rscript with testthat, dplyr, readr, jsonlite, tibble.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
RSCRIPT=${RSCRIPT:-Rscript}
cmp -s "$here/starter/tests/test-lab.R" "$here/solution/tests/test-lab.R" || { echo "REFUSED: test files differ"; exit 2; }
cmp -s "$here/starter/run-tests.R" "$here/solution/run-tests.R" || { echo "REFUSED: runners differ"; exit 2; }
run() { # dir -> rc, log
  ( cd "$1" && "$RSCRIPT" run-tests.R </dev/null 2>&1 ); }
for v in starter solution; do
  out=$(run "$here/$v"); rc=$?
  printf '%s\n' "$out" > "$here/run-$v.log"
  echo "$v exit=$rc | $(printf '%s\n' "$out" | grep -E '^Lab: penguin summary' | head -n 1)"
  eval "rc_$v=$rc"
done
ok=1
if [ "${MUTANTS:-0}" = 1 ]; then
  t=$(mktemp -d)
  mk() { cp -r "$here/solution" "$t/$1"; sed -i "$2" "$t/$1/R/penguins.R"; }
  mk popsd 's/stats::sd)/function(x) sqrt(mean((x - mean(x))^2)))/;s/list(mean = mean, sd = stats::sd)/list(mean = mean, sd = function(x) sqrt(mean((x - mean(x))^2)))/'
  mk dropsex 's/dplyr::if_all(dplyr::all_of(numeric_cols), ~ !is.na(.x))/dplyr::if_all(dplyr::everything(), ~ !is.na(.x))/'
  for m in popsd dropsex; do
    cmp -s "$t/$m/R/penguins.R" "$here/solution/R/penguins.R" && { echo "mutant $m: sed changed nothing, REFUSED"; ok=0; continue; }
    out=$(run "$t/$m"); rc=$?
    echo "mutant $m exit=$rc | $(printf '%s\n' "$out" | grep -E '^Lab: penguin summary' | head -n 1)"
    [ "$rc" -ne 0 ] || ok=0
  done
fi
[ "$rc_starter" -ne 0 ] && [ "$rc_solution" -eq 0 ] && [ "$ok" = 1 ] && { echo "PROOF OK: starter fails, solution passes"; exit 0; }
echo "PROOF FAILED"; exit 1
