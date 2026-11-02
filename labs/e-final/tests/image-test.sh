#!/usr/bin/env bash
# image-test.sh TAG : fresh-container test. Starter FAILS, solution PASSES, 5 planted cheats are refused, first demo <= 300 s.
# Each run is a new UNPRIVILEGED container (docker run --rm, default seccomp and apparmor, no added caps): no bwrap, no user namespaces, like a Coursera lab.
set -uo pipefail
repo=$(cd "$(dirname "$0")/../../.." && pwd); tag="${1:?tag}"; fail=0
g() { docker run --rm -e GRADER_DEBUG=1 --network none --entrypoint "" --user coder -e HOME=/home/coder -v "$repo:/work:ro" "$tag" bash /work/labs/e-final/tests/run.sh "$1"; }
t0=$(date +%s)
g /work/labs/e-final/solution >/tmp/img-sol.out 2>&1; rc=$?
t1=$(date +%s)
[ "$rc" -eq 0 ] && echo "PASS 1 solution passes (rc=0)" || { echo "FAIL 1 solution rc=$rc: $(tail -n 2 /tmp/img-sol.out)"; sed "s/^/  sol| /" /tmp/img-sol.out | tail -n 40; fail=1; }
[ $((t1-t0)) -le 300 ] && echo "PASS 2 first demo took $((t1-t0)) s (<= 300)" || { echo "FAIL 2 first demo took $((t1-t0)) s"; fail=1; }
g /work/labs/e-final/starter >/tmp/img-st.out 2>&1; rc=$?
[ "$rc" -eq 1 ] && echo "PASS 3 starter fails (rc=1)" || { echo "FAIL 3 starter rc=$rc, want 1"; fail=1; }
caught=0
ncheats=0
for d in "$repo"/labs/e-final/tests/cheats/*/; do
  c=$(basename "$d"); ncheats=$((ncheats+1))
  g "/work/labs/e-final/tests/cheats/$c" >/tmp/img-c.out 2>&1; [ "$?" -eq 1 ] && caught=$((caught+1)) || echo "plant $c NOT caught"
done
[ "$ncheats" -gt 0 ] && [ "$caught" -eq "$ncheats" ] && echo "PASS 4 $caught/$ncheats plants refused" || { echo "FAIL 4 $caught/$ncheats plants refused"; fail=1; }
# 5. the container-sandbox flag unset must still refuse to compile unsandboxed (no bwrap here, so the grade FAILS with the refusal)
docker run --rm --network none --entrypoint "" --user coder -e HOME=/home/coder -e GRADER_SANDBOX= -e GRADER_DEBUG=1 -v "$repo:/work:ro" "$tag" bash /work/labs/e-final/tests/run.sh /work/labs/e-final/solution >/tmp/img-nf.out 2>&1; rc=$?
[ "$rc" -ne 0 ] && /usr/bin/grep -q "never compiled unsandboxed" /tmp/img-nf.out && echo "PASS 5 flag unset refuses unsandboxed (rc=$rc)" || { echo "FAIL 5 flag unset rc=$rc"; fail=1; }
# 6. container flag set but marker absent must refuse too; 7. container mode announces itself
docker run --rm --network none --entrypoint "" --user coder -e HOME=/home/coder -e GRADER_DEBUG=1 -v "$repo:/work:ro" "$tag" bash -c "sudo rm -f /etc/ads-lab-container-sandbox; bash /work/labs/e-final/tests/run.sh /work/labs/e-final/solution" >/tmp/img-nm.out 2>&1; rc=$?
[ "$rc" -ne 0 ] && /usr/bin/grep -q "never compiled unsandboxed" /tmp/img-nm.out && echo "PASS 6 flag set, marker absent refuses (rc=$rc)" || { echo "FAIL 6 marker absent rc=$rc"; fail=1; }
/usr/bin/grep -q "grader: sandbox=container" /tmp/img-sol.out && echo "PASS 7 container mode announces itself" || { echo "FAIL 7 no sandbox=container line"; fail=1; }
exit $fail
