#!/usr/bin/env bash
# Both recorded runs of the lab: grade.sh on the starter and on the solution, with the grader's copy of the tests.
# Proof = starter exits non-zero (names its failing testsets), solution exits 0 with 73 checks, test files byte-identical.
# JULIA: a julia >= 1.13 (else julia-docker.sh, the pinned sandbox image). Logs hold no host paths (scratch dirs are masked).
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
if [ -z "${JULIA:-}" ]; then if command -v julia >/dev/null; then JULIA=julia; else JULIA=$here/julia-docker.sh; fi; fi
export JULIA GRADER_DIR=$here
cmp -s "$here/starter/test/runtests.jl" "$here/solution/test/runtests.jl" || { echo "REFUSED: test files differ"; exit 2; }
for v in starter solution; do
  out=$(bash "$here/grade.sh" "$here/$v" 2>&1); rc=$?
  printf '%s\n' "$out" | sed -E "s#$here#<lab>#g; s#/[^ :]*/work/#<work>/#g" > "$here/run-$v.log"
  echo "$v exit=$rc | $(tail -n 1 "$here/run-$v.log")"
  eval "rc_$v=$rc"
done
[ "$rc_starter" -ne 0 ] && [ "$rc_solution" -eq 0 ] && { echo "PROOF OK: starter fails, solution passes"; exit 0; }
echo "PROOF FAILED"; exit 1
