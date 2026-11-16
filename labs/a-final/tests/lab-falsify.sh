#!/usr/bin/env bash
# lab-falsify.sh : plant defects; the grader must refuse each (exit != 0). Exit 0 only if every planted defect is refused.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd); S=$here/../solution; W=$(mktemp -d); trap 'rm -rf "${W:?}"' EXIT
bad=0
chk() { # name want_exit dir [tests]
  LAB_TESTS=${4:-$here/lab_tests.rs} "$here/lab-run.sh" "$3" >"$W/out" 2>&1; rc=$?
  if [ "$rc" -eq "$2" ]; then echo "REFUSED $1 (exit $rc)"; else echo "NOT REFUSED $1 (exit $rc, want $2)"; bad=1; fi; }
mk() { rm -rf "$W/$1"; mkdir "$W/$1"; cp -r "$S/src" "$S/Cargo.toml" "$S/Cargo.lock" "$W/$1/"; }
mk wrong;  sed -i 's/p2::ols_ndarray(x, y)/{ let (a, b) = p2::ols_ndarray(x, y); (a, b + 0.01) }/' "$W/wrong/src/lib.rs"
chk wrong-answer 1 "$W/wrong"
mk stub;   sed -i 's/p2::ols_ndarray(x, y)/todo!()/' "$W/stub/src/lib.rs"
chk stub-left-in 1 "$W/stub"
mk const;  sed -i 's/\.height()/.height() + 1/' "$W/const/src/lib.rs"
chk off-by-one 1 "$W/const"
printf '#[test]\nfn lab_empty() {}\n' > "$W/empty.rs"; : > "$W/zero.rs"; printf 'use lab_a_final::*;\n' > "$W/zero.rs"
mk zero
chk zero-test-suite 2 "$W/zero" "$W/zero.rs"
chk single-trivial-test 2 "$W/zero" "$W/empty.rs"
mk broke;  echo 'fn syntax error' >> "$W/broke/src/lib.rs"
chk does-not-compile 1 "$W/broke"
[ "$bad" -eq 0 ] && echo "falsify: all planted defects refused" || echo "falsify: RED"; exit $bad
