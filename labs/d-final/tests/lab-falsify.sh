#!/usr/bin/env bash
# lab-falsify.sh : plant defects; the grader must refuse each. Exit 0 only if every planted defect is refused.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd); S=$here/../solution; W=$(mktemp -d); trap 'rm -rf "${W:?}"' EXIT
bad=0
chk() { # name want_exit dir [tests dir]
  LAB_TESTS=${4:-$here/lab} "$here/lab-run.sh" "$3" >"$W/out" 2>&1 </dev/null; rc=$?
  if [ "$rc" -eq "$2" ]; then echo "REFUSED $1 (exit $rc)"; else echo "NOT REFUSED $1 (exit $rc, want $2)"; bad=1; fi; }
mk() { rm -rf "$W/$1"; mkdir "$W/$1"; cp -r "$S/src" "$W/$1/"; }
mk wrong; sed -i 's/\.size$/.size + 1/' "$W/wrong/src/lab/Lab.kt"
chk wrong-answer 1 "$W/wrong"
mk stub; sed -i 's/fun massOnFlipper(path: String): Fit {/fun massOnFlipper(path: String): Fit {\n    TODO("left in")/' "$W/stub/src/lab/Lab.kt"
chk stub-left-in 1 "$W/stub"
mk broke; echo 'fun syntax error' >> "$W/broke/src/lab/Lab.kt"
chk does-not-compile 1 "$W/broke"
mkdir "$W/zero"; printf 'package lab\n' > "$W/zero/Empty.kt"
mk z1
chk zero-test-suite 2 "$W/z1" "$W/zero"
mkdir "$W/one"; printf 'package lab\nimport org.junit.jupiter.api.Test\nclass One { @Test fun lab_only() {} }\n' > "$W/one/One.kt"
chk single-trivial-test 2 "$W/z1" "$W/one"
[ "$bad" -eq 0 ] && echo "falsify: all planted defects refused" || echo "falsify: RED"; exit $bad
