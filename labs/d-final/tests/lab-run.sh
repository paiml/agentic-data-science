#!/usr/bin/env bash
# lab-run.sh LABDIR : grade LABDIR/src against tests/lab/*.kt (or $LAB_TESTS dir) with Gradle + JUnit.
# Exit 0 = every task passes, 1 = a task failed (each named), 2 = could not measure (zero tests never passes).
# LAB_JDK (default 25, the course pin) selects the toolchain; LAB_GRADLE_OPTS defaults to --offline.
set -uo pipefail
D=${1:?lab dir (starter or solution)}; D=$(cd "$D" && pwd)
here=$(cd "$(dirname "$0")" && pwd); LAB=$(cd "$here/.." && pwd); REPO=$(cd "$LAB/../.." && pwd)
TESTS=${LAB_TESTS:-$here/lab}
[ -n "$(ls "$D"/src/lab/*.kt 2>/dev/null)" ] || { echo "NOT MEASURED: $D/src/lab/*.kt missing"; exit 2; }
[ -d "$TESTS" ] || { echo "NOT MEASURED: tests dir $TESTS missing"; exit 2; }
(cd "$REPO/datasets/penguins" && sha256sum -c --quiet SHA256SUMS) >/dev/null 2>&1 || { echo "NOT MEASURED: penguins SHA256SUMS mismatch"; exit 2; }
T=$(mktemp -d); trap 'rm -rf "${T:?}"' EXIT
P=$T/labs/d-final; mkdir -p "$P/solution" "$P/tests"
cp -r "$LAB/gradle" "$LAB/gradlew" "$LAB/build.gradle.kts" "$LAB/settings.gradle.kts" "$P/"
cp -r "$D/src" "$P/solution/"; cp -r "$TESTS/." "$P/tests/lab/" 2>/dev/null || { mkdir -p "$P/tests/lab"; cp -r "$TESTS/." "$P/tests/lab/"; }
ln -s "$REPO/kotlin" "$T/kotlin"; ln -s "$REPO/datasets" "$T/datasets"
stub=0; grep -nE 'TODO\(|NotImplementedError' "$D"/src/lab/*.kt >/dev/null && stub=1
out=$(cd "$P" && ./gradlew ${LAB_GRADLE_OPTS---offline} test -Pjdk="${LAB_JDK:-25}" -Pvariant=solution 2>&1); rc=$?
R=$P/build/test-results/test
if ! ls "$R"/*.xml >/dev/null 2>&1; then
  if echo "$out" | grep -qE "Task :test (NO-SOURCE|UP-TO-DATE)|No tests found|did not discover any tests|BUILD SUCCESSFUL"; then echo "NOT MEASURED: zero tests ran (a zero-test suite never passes)"; exit 2; fi
  echo "FAIL build (does not compile or toolchain missing)"; echo "$out" | grep -E "error|Unresolved|Cannot find" | head -5; echo "lab: 0 tasks pass"; exit 1
fi
n=0; fail=0; stubf=0
while read -r res name; do
  n=$((n+1)); echo "$res $name"; [ "$res" = PASS ] || fail=$((fail+1))
done < <(awk '/<testcase / { match($0, /name="[A-Za-z0-9_]*[(]*[)]*"/); nm=substr($0, RSTART+6, RLENGTH-7); sub(/[(][)]/, "", nm); if ($0 ~ /\/>$/) { print "PASS", nm; next } bad=0; while ((getline l) > 0) { if (l ~ /<failure|<error|<skipped/) bad=1; if (l ~ /<\/testcase>/) break } print (bad ? "FAIL" : "PASS"), nm }' "$R"/*.xml)
[ "$n" -ge 1 ] || { echo "NOT MEASURED: zero tests ran (a zero-test suite never passes)"; exit 2; }
[ "$stub" -eq 0 ] || { echo "FAIL stub (TODO left in src/lab)"; stubf=1; }
[ "$n" -ge 3 ] || { echo "NOT MEASURED: only $n tests ran, lab needs 3"; exit 2; }
echo "lab: $((n-fail))/$n tasks pass"; [ "$fail" -eq 0 ] && [ "$stubf" -eq 0 ] && [ "$rc" -eq 0 ] && exit 0 || exit 1
