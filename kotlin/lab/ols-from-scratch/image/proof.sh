#!/usr/bin/env bash
# Inside the image, network none: run both variants and assert the JUnit XML, not just exit codes.
set -u
cd /w/kotlin/lab/ols-from-scratch
FAIL7="lengthMismatchIsRefused residualSumOfAWrongLineIsNotZero constantXIsRefused singlePointIsRefused penguinFitMatchesGolden exactLineIsRecovered residualsOfAnOlsFitSumToZero"
xml=build/test-results/test/TEST-lab.OlsLabTest.xml
gradle --offline -Pvariant=starter clean test >/tmp/s.log 2>&1; rc=$?
[ "$rc" = 1 ] || { echo "FAIL starter exit $rc (want 1)"; exit 1; }
grep -q 'tests="8"' "$xml" && grep -q 'failures="7"' "$xml" || { echo "FAIL starter counts"; exit 1; }
for t in $FAIL7; do
  grep -A2 "testcase name=\"$t()\"" "$xml" | grep -q '<failure' || { echo "FAIL starter: $t did not fail"; exit 1; }
done
gradle --offline -Pvariant=solution clean test >/tmp/o.log 2>&1; rc=$?
[ "$rc" = 0 ] || { echo "FAIL solution exit $rc (want 0)"; exit 1; }
grep -q 'tests="8"' "$xml" && grep -q 'failures="0"' "$xml" && grep -q 'errors="0"' "$xml" || { echo "FAIL solution counts"; exit 1; }
echo "proof: starter exit 1 (7/8 named failures), solution exit 0 (8/8) OK"
