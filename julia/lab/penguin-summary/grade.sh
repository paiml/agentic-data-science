#!/usr/bin/env bash
# Grader entry point: grade.sh [LAB_DIR]  (default: ./starter). Exit 0 = every check passed.
# Runs from the GRADER side (/grader/grade.sh in the sandbox image), never from the learner's /workspace.
# GRADER_DIR (default /grader, no other fallback) holds run.jl (the runner) and solution/test/runtests.jl (the tests).
# The learner's tree is graded against the grader's tests, and the counts are read from a result file only the
# runner writes (run.jl). The learner's stdout and exit code are never parsed: learner code runs in the runner's
# process and can print a pass line and call exit(0). No result file, or a wrong nonce, is a FAIL. Fewer than
# MIN_TOTAL passes, or any fail/error, or a non-zero exit, is a FAIL.
# Residual limit: the learner's code shares the runner's process, so it could in principle find and write the result
# file; the nonce and path are only on the runner's stdin and in a directory the learner never names. The real boundary is
# the sandbox (no network, no host mounts, learner tree writable, /grader read-only).
set -uo pipefail
dir=${1:-./starter}
JULIA=${JULIA:-julia}
MIN_TOTAL=${MIN_TOTAL:-73}
G=${GRADER_DIR:-/grader}
tests=$G/solution/test/runtests.jl
runner=$G/run.jl
[ -f "$tests" ] && [ -f "$runner" ] || { echo "GRADE: REFUSED, no grader copy of runtests.jl or run.jl in $G"; exit 2; }
[ -d "$dir/src" ] || { echo "GRADE: REFUSED, no src/ in $dir"; exit 2; }
if [ -e "$dir/test/runtests.jl" ] && ! cmp -s "$dir/test/runtests.jl" "$tests"; then echo "GRADE: FAIL (test/runtests.jl was changed or emptied; graded against the grader copy only)"; exit 1; fi
base=$(mktemp -d); trap 'rm -rf "${base:?}"' EXIT
work=$base/work; res=$base/res; mkdir -p "$work" "$res"
cp -R "$dir/." "$work/"
mkdir -p "$work/test"; cp "$tests" "$work/test/runtests.jl"
cd "$work" || exit 2
nonce=$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')
result=$res/result-$nonce
export JULIA_PKG_OFFLINE=${JULIA_PKG_OFFLINE:-true}
"$JULIA" --project=. -e 'using Pkg; Pkg.instantiate()' >/dev/null 2>&1
out=$(printf '%s\t%s\n' "$result" "$nonce" | "$JULIA" --project=. "$runner" "$work/test/runtests.jl" 2>&1); rc=$?
printf '%s\n' "$out" | tail -n 25
[ -f "$result" ] || { echo "GRADE: FAIL (the runner wrote no result: the run ended early or crashed)"; exit 1; }
read -r got_nonce pass fail error < "$result"
[ "$got_nonce" = "$nonce" ] || { echo "GRADE: FAIL (result file has the wrong nonce)"; exit 1; }
pass=${pass#pass=}; fail=${fail#fail=}; error=${error#error=}
case "$pass$fail$error" in *[!0-9]*|"") echo "GRADE: FAIL (result file unreadable)"; exit 1;; esac
if [ "$rc" -ne 0 ]; then echo "GRADE: FAIL (exit $rc)"; exit "$rc"; fi
if [ "$fail" -ne 0 ] || [ "$error" -ne 0 ]; then echo "GRADE: FAIL ($fail failed, $error errored)"; exit 1; fi
if [ "$pass" -lt "$MIN_TOTAL" ]; then echo "GRADE: FAIL (ran $pass checks, need >= $MIN_TOTAL)"; exit 1; fi
echo "GRADE: PASS ($pass checks)"; exit 0
