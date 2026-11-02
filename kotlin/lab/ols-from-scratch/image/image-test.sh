#!/usr/bin/env bash
# image-test.sh TAG : fresh-container test, network off, unprivileged. Starter FAILS (7 of 8), solution PASSES (8 of 8),
# 5 planted wrong solutions are refused (each exits 1), and the first demo (solution run in a new container) takes <= 300 s.
set -uo pipefail
tag="${1:?tag}"; fail=0; xml=build/test-results/test/TEST-lab.OlsLabTest.xml
run() { # $1 variant -> exit code of the suite in a NEW container; leaves the JUnit XML in /tmp/img-xml.$1
  docker run --rm --network none --entrypoint "" "$tag" bash -c \
    "gradle --offline -q -Pvariant=$1 clean test >/tmp/o.log 2>&1; rc=\$?; cat $xml 2>/dev/null >&2 || true; exit \$rc" 2>"/tmp/img-xml.$1"
}
t0=$(date +%s); run solution; rc=$?; t1=$(date +%s)
{ [ "$rc" -eq 0 ] && grep -q 'tests="8"' "/tmp/img-xml.solution" && grep -q 'failures="0"' "/tmp/img-xml.solution"; } \
  && echo "PASS 1 solution passes (rc=0, 8 of 8)" || { echo "FAIL 1 solution rc=$rc"; fail=1; }
[ $((t1-t0)) -le 300 ] && echo "PASS 2 first demo took $((t1-t0)) s (<= 300)" || { echo "FAIL 2 first demo took $((t1-t0)) s"; fail=1; }
run starter; rc=$?
{ [ "$rc" -eq 1 ] && grep -q 'tests="8"' "/tmp/img-xml.starter" && grep -q 'failures="7"' "/tmp/img-xml.starter"; } \
  && echo "PASS 3 starter fails (rc=1, 7 of 8)" || { echo "FAIL 3 starter rc=$rc, want 1 with 7 of 8 failing"; fail=1; }
caught=0
for c in hardcoded-golden zero-residual no-validation wrong-sign mean-only; do
  run "cheat-$c"; rc=$?
  { [ "$rc" -eq 1 ] && grep -q '<failure' "/tmp/img-xml.cheat-$c"; } && caught=$((caught+1)) || echo "plant $c NOT caught (rc=$rc)"
done
[ "$caught" -eq 5 ] && echo "PASS 4 5/5 plants refused" || { echo "FAIL 4 $caught/5 plants refused"; fail=1; }
exit $fail
