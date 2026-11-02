#!/usr/bin/env bash
# image-test.sh TAG : fresh-container test. Starter FAILS, solution PASSES, 5 planted cheats are refused, first demo <= 300 s.
# Each run is a new container (docker run --rm). seccomp, apparmor and systempaths are relaxed, SYS_ADMIN added, only so the grader's bwrap can create its namespaces.
set -uo pipefail
repo=$(cd "$(dirname "$0")/../../.." && pwd); tag="${1:?tag}"; fail=0
g() { docker run --rm -e GRADER_DEBUG=1 --network none --entrypoint "" --user coder -e HOME=/home/coder --cap-add SYS_ADMIN --security-opt seccomp=unconfined --security-opt apparmor=unconfined --security-opt systempaths=unconfined -v "$repo:/work:ro" "$tag" bash /work/labs/e-final/tests/run.sh "$1"; }
t0=$(date +%s)
g /work/labs/e-final/solution >/tmp/img-sol.out 2>&1; rc=$?
t1=$(date +%s)
[ "$rc" -eq 0 ] && echo "PASS 1 solution passes (rc=0)" || { echo "FAIL 1 solution rc=$rc: $(tail -n 2 /tmp/img-sol.out)"; sed "s/^/  sol| /" /tmp/img-sol.out | tail -n 40; fail=1; }
[ $((t1-t0)) -le 300 ] && echo "PASS 2 first demo took $((t1-t0)) s (<= 300)" || { echo "FAIL 2 first demo took $((t1-t0)) s"; fail=1; }
g /work/labs/e-final/starter >/tmp/img-st.out 2>&1; rc=$?
[ "$rc" -eq 1 ] && echo "PASS 3 starter fails (rc=1)" || { echo "FAIL 3 starter rc=$rc, want 1"; fail=1; }
caught=0
for c in by-elab-exec custom-axiom hijack-add true-statement unsafecast-skipkernel; do
  g "/work/labs/e-final/tests/cheats/$c" >/tmp/img-c.out 2>&1; [ "$?" -eq 1 ] && caught=$((caught+1)) || echo "plant $c NOT caught"
done
[ "$caught" -eq 5 ] && echo "PASS 4 5/5 plants refused" || { echo "FAIL 4 $caught/5 plants refused"; fail=1; }
exit $fail
