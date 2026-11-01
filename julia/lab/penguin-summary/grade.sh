#!/usr/bin/env bash
# Grader entry point: grade.sh [LAB_DIR]  (default: ./starter). Exit 0 = every check passed.
# Runs from the GRADER side (/grader/grade.sh in the sandbox image), never from the learner's /workspace.
# GRADER_DIR (default /grader, no other fallback) holds run.jl, serve.jl, wire.jl, shim/AgenticDS.jl and
# solution/{Project.toml,Manifest.toml,test/runtests.jl,data}.
# Two processes. The VERDICT process (run.jl) loads only the grader shim package and runs the grader's own runtests.jl
# in place; it never loads learner code. The learner's package runs in a CHILD process (serve.jl) that answers the
# shim's calls over a loopback socket with values only (a restricted JSON of DataFrames and strings, never
# Serialization). Learner stdout, exit code, globals and __init__ cannot reach the verdict process. A child that
# crashes, hangs or sends junk is an error in a testset, so a FAIL. The learner's stdout and exit code are never parsed.
# MIN_TOTAL (73) passes, no fail/error, exit 0 and a result file with this run's nonce are all required.
# Residual limit: the child still shares a machine with the verdict process (loopback, same uid); the sandbox
# (no network beyond loopback, no host mounts, /grader read-only) is the outer boundary.
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
# the verdict process's project: the solution's Project.toml and Manifest, with the grader shim as the AgenticDS source
gp=$base/gproj; mkdir -p "$gp/src"
cp "$G/solution/Project.toml" "$G/solution/Manifest.toml" "$gp/" 2>/dev/null
cp "$G/shim/AgenticDS.jl" "$G/wire.jl" "$gp/src/"
cd "$gp" || exit 2
nonce=$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')
result=$res/result-$nonce
export JULIA_PKG_OFFLINE=${JULIA_PKG_OFFLINE:-true}
"$JULIA" --project=. -e 'using Pkg; Pkg.instantiate()' >/dev/null 2>&1
(cd "$work" && "$JULIA" --project=. -e 'using Pkg; Pkg.instantiate()' >/dev/null 2>&1)
# the tests run IN PLACE from the grader dir, so their data path (../data) is the grader's, not the learner's copy
out=$(printf '%s\t%s\n' "$result" "$nonce" | timeout "${GRADE_TIMEOUT:-600}" "$JULIA" --project=. "$runner" "$tests" "$work" "$G/serve.jl" "$G/wire.jl" 2>&1); rc=$?
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
