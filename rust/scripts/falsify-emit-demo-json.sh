#!/usr/bin/env bash
# falsify-emit-demo-json.sh: planted faults for rust/scripts/emit-demo-json.sh. Each arm must be refused with no
# file written; the happy arm must write valid JSON whose sha256 values match. Stub commands only: no network, no cargo.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
EMIT="$HERE/emit-demo-json.sh"
T=$(mktemp -d); trap 'rm -rf "${T:?}"' EXIT
fail=0
ok() { echo "ok   $1"; }
bad() { echo "FAIL $1" >&2; fail=1; }
mkdir -p "$T/crate" "$T/bin"
# a stub cargo: `run` prints the example name and a ready line; `test` prints a timing that changes every call, in the
# real harness format, and STUB_TEST_MODE plants a fault (ignored, missing, rename, nores = no `test result:` line)
cat >"$T/bin/cargo" <<'STUB'
#!/usr/bin/env bash
res() { printf '\ntest result: ok. %s passed; 0 failed; %s ignored; 0 measured; 0 filtered out; finished in 0.%02ds\n' "$1" "$2" $((RANDOM % 90 + 10)); }
case "$1" in
  run) echo "stub-run $*"; echo "ready-line OK";;
  test)
    case "${STUB_TEST_MODE:-}" in
      ignored) printf 'running 2 tests\ntest b ... ok\ntest a ... ignored\n'; res 1 1;;
      missing) printf 'running 1 test\ntest b ... ok\n'; res 1 0;;
      rename) printf 'running 2 tests\ntest b ... ok\ntest c ... ok\n'; res 2 0;;
      nores) printf 'running 1 test\ntest b ... ok\n';;
      *) printf 'running 2 tests\ntest b ... ok\ntest a ... ok\n'; res 2 0;;
    esac;;
esac
STUB
chmod +x "$T/bin/cargo"
# row layout: idx|name|example|source|from|to|RUN|WAIT|e1|e2|n1|n2
GOOD1='01|one|ex-one|examples/one.rs|1|2|echo hello world|hello|a|b|n1|n2'
GOOD2='02|two|ex-two|src/two.rs|3|4||ready-line OK|a|b|n1|n2'
GOOD3='03|tests|ex-two|tests/p9.rs|5|6|cargo test --locked --offline --test p9|2 passed; 0 failed; 0 ignored|a|b|n1|n2'
run() { # run NAME BATCHFILE... -> sets rc and $T/err
  rm -f "${T:?}/out.json"
  PATH="$T/bin:$PATH" ADS_CRATE_DIR="$T/crate" "$EMIT" "$T/out.json" "${@:2}" >"$T/so" 2>"$T/err"; rc=$?
}
refused() { # refused NAME BATCH [stderr-substring]
  run "$1" "$2"
  if [ "$rc" -ne 0 ] && [ ! -e "$T/out.json" ] && { [ -z "${3:-}" ] || grep -qF -- "$3" "$T/err"; }; then ok "$1"; else bad "$1 (rc=$rc, file=$([ -e "$T/out.json" ] && echo yes || echo no), err=$(tr '\n' ' ' <"$T/err"))"; fi
}
mk() { local f="$T/$1.batch"; shift; printf '%s\n' "$@" >"$f"; echo "$f"; }

# arm 1: non-zero exit
refused "nonzero-exit" "$(mk b1 "$GOOD1" '05|boom|ex|s.rs|1|2|sh -c "echo partial; exit 3"|partial|a|b|n1|n2')" "05"
# arm 2: empty stdout
refused "empty-stdout" "$(mk b2 "$GOOD1" '06|quiet|ex|s.rs|1|2|true|x|a|b|n1|n2')" "06"
# arm 3: WAIT string absent, message names the row and the string
refused "wait-absent" "$(mk b3 "$GOOD1" '07|nomatch|ex|s.rs|1|2|echo actual output|never printed|a|b|n1|n2')" "b3-07"
refused "wait-absent-names-string" "$T/b3.batch" "never printed"
# arm 4: malformed rows (11 and 13 fields) and a missing batch file
refused "short-row" "$(mk b4 "$GOOD1" '08|short|ex|s.rs|1|2|echo hi|hi|a|b|n1')" "field"
refused "long-row" "$(mk b5 "$GOOD1" '09|long|ex|s.rs|1|2|echo hi|hi|a|b|n1|n2|extra')" "field"
refused "missing-batch" "$T/does-not-exist.batch" "batch"
# arm 5: an empty WAIT is refused and the message names the row
refused "empty-wait-refused" "$(mk b6 "$GOOD1" '04|emptywait|ex-two|src/two.rs|3|4|echo anything||a|b|n1|n2')" "b6-04"
# arm 6: duplicate ids, and an idx that is not two digits
refused "duplicate-id" "$(mk b7 "$GOOD1" "$GOOD1")" "duplicate"
refused "idx-not-two-digits" "$(mk b8 '1|short-idx|ex|s.rs|1|2|echo hi|hi|a|b|n1|n2')" "idx"
refused "idx-not-digits" "$(mk b9 'ab|alpha-idx|ex|s.rs|1|2|echo hi|hi|a|b|n1|n2')" "idx"
# arm 7: RUN fields run under pipefail (a pipe itself cannot appear in a RUN field: `|` separates the fields)
PF='10|pipefail|ex|s.rs|1|2|if [[ $SHELLOPTS == *pipefail* ]]; then echo pipefail-on; fi|pipefail-on|a|b|n1|n2'
run pipefail "$(mk b10 "$PF")"
[ "$rc" -eq 0 ] && ok "run field runs under pipefail" || bad "run field runs under pipefail (rc=$rc: $(cat "$T/err"))"
refused "pipe-in-run-refused" "$(mk b11 '11|pipe|ex|s.rs|1|2|false | cat|x|a|b|n1|n2')" "field"
# arm 8: cargo test facts: an ignored test, a missing test, no `test result:` line
WEAK='03|tests|ex-two|tests/p9.rs|5|6|cargo test --locked --offline --test p9|test b ... ok|a|b|n1|n2'
STUB_TEST_MODE=ignored refused "ignored-test-refused" "$(mk b12 "$WEAK")" "ignored"
STUB_TEST_MODE=nores refused "no-test-result-line-refused" "$T/b12.batch" "test result"
STUB_TEST_MODE=missing refused "missing-test-wait-fails" "$(mk b13 "$GOOD3")" "2 passed"

# happy path: run command, default cargo run, cargo test; file name m1.batch gives ids m1-NN
B=$(mk m1 "$GOOD1" "$GOOD2" "$GOOD3")
run happy "$B"
if [ "$rc" -eq 0 ] && jq -e . "$T/out.json" >/dev/null 2>&1; then ok "happy-valid-json"; else bad "happy-valid-json (rc=$rc: $(cat "$T/err"))"; fi
chk() { jq -e "$2" "$T/out.json" >/dev/null 2>&1 && ok "$1" || bad "$1"; }
chk "schema+course" '.schema=="demo-json/v1" and .course=="ads-c01-rust" and (.demos|length)==3'
chk "ids m<M>-<idx>" '[.demos[].id]==["m1-01","m1-02","m1-03"]'
chk "fields" '.demos[0]|(.command=="echo hello world" and .exit==0 and .wait=="hello" and .example=="ex-one" and .source=="examples/one.rs" and .plots==[])'
chk "default run command" '.demos[1].command=="cargo run --locked --offline --example ex-two"'
chk "test normalized, sorted" '.demos[2]|(.normalized==true and (.stdout|contains("finished in")|not) and (.stdout|contains("test a ... ok\ntest b ... ok")))'
chk "test facts recorded" '.demos[2].tests|(.passed==2 and .failed==0 and .ignored==0 and (.names_sha256|test("^[0-9a-f]{64}$")))'
chk "non-test row has no tests record" '.demos[0].tests==null'
names_ok=$(jq -r '.demos[2].tests.names_sha256' "$T/out.json")
# a renamed test changes names_sha256
STUB_TEST_MODE=rename run rename "$T/m1.batch"
[ "$rc" -eq 0 ] && [ "$(jq -r '.demos[2].tests.names_sha256' "$T/out.json" 2>/dev/null)" != "$names_ok" ] && ok "renamed test changes names_sha256" || bad "renamed test changes names_sha256 (rc=$rc: $(cat "$T/err"))"
sha_ok=1
run happy "$B"
for i in 0 1 2; do
  want=$(jq -j ".demos[$i].stdout" "$T/out.json" | sha256sum | cut -d' ' -f1)
  got=$(jq -r ".demos[$i].stdout_sha256" "$T/out.json")
  [ "$want" = "$got" ] || sha_ok=0
done
[ "$sha_ok" = 1 ] && ok "sha256 matches stdout" || bad "sha256 matches stdout"
# the batch file name gives the module: m2.batch -> m2-NN
cp "$T/m1.batch" "$T/m2.batch"; run m2 "$T/m2.batch"
chk "id from file name" '.demos[0].id=="m2-01"'
# determinism: the test row is identical across two runs despite changing timings
run det "$T/m1.batch"; a=$(jq -r '.demos[2].stdout_sha256' "$T/out.json"); run det "$T/m1.batch"; b=$(jq -r '.demos[2].stdout_sha256' "$T/out.json")
[ "$a" = "$b" ] && ok "test sha stable across timings" || bad "test sha stable across timings"
# ADS_ROOT: the emitter exports it, and rows 07/09 refuse an unset one (cd "${ADS_ROOT:?}")
AR='12|adsroot|ex|s.rs|1|2|cd "${ADS_ROOT:?}" && echo root-ok|root-ok|a|b|n1|n2'
run adsroot "$(mk b14 "$AR")"; [ "$rc" -eq 0 ] && ok "emitter exports ADS_ROOT" || bad "emitter exports ADS_ROOT (rc=$rc)"
env -u ADS_ROOT bash -o pipefail -c 'cd "${ADS_ROOT:?}" && echo reached' >/dev/null 2>&1 && bad "unset ADS_ROOT refused" || ok "unset ADS_ROOT refused"
n=$(grep -c 'cd "${ADS_ROOT:?}"' "$HERE/../../demos/rust-native/m1.batch"); ! grep -q 'cd "\$ADS_ROOT"' "$HERE/../../demos/rust-native/m1.batch" && [ "$n" -ge 2 ] && ok "m1 rows 07/09 guard ADS_ROOT" || bad "m1 rows 07/09 guard ADS_ROOT"
# gate-rust output: lab PASS/FAIL lines arrive in parallel order; the sha must not depend on it
cat >"$T/bin/make" <<'STUB'
#!/usr/bin/env bash
printf 'cov table\nstarter_exit=1\n'; printf 'starter_FAIL %s\n' a b c | shuf; printf 'solution_exit=0\n'; printf 'solution_PASS %s\n' x y z | shuf; echo "rust gate OK"
STUB
chmod +x "$T/bin/make"
GR='13|gate|ex|s.rs|1|2|make gate-rust|rust gate OK|a|b|n1|n2'
run gr "$(mk b15 "$GR")"; a=$(jq -r '.demos[0].stdout_sha256' "$T/out.json"); run gr "$T/b15.batch"; b=$(jq -r '.demos[0].stdout_sha256' "$T/out.json")
a2=$a; for _ in 1 2 3 4 5 6; do run gr "$T/b15.batch"; a2=$(jq -r '.demos[0].stdout_sha256' "$T/out.json"); [ "$a2" = "$a" ] || break; done
[ "$a" = "$b" ] && [ "$a2" = "$a" ] && ok "gate-rust sha stable across lab order" || bad "gate-rust sha stable across lab order"
# a stale OUT from an earlier run must not survive a refused run
echo stale >"$T/out.json"; PATH="$T/bin:$PATH" ADS_CRATE_DIR="$T/crate" "$EMIT" "$T/out.json" "$T/b3.batch" >/dev/null 2>&1
[ ! -e "$T/out.json" ] && ok "stale output removed" || bad "stale output removed"
[ "$fail" -eq 0 ] && echo "falsify-emit-demo-json OK" || { echo "falsify-emit-demo-json RED" >&2; exit 1; }
