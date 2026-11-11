#!/usr/bin/env bash
# falsify-emit-demo-json.sh: planted faults for rust/scripts/emit-demo-json.sh. Each refusal arm must exit non-zero with
# no file written; the happy arm must write a row in the shared demo-json/v1 row shape. Stub commands only: no network,
# no real cargo.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
EMIT="$HERE/emit-demo-json.sh"
T=$(mktemp -d "${TMPDIR:-$HOME}/emit-falsify.XXXXXX"); trap 'rm -rf "${T:?}"' EXIT
fail=0
ok() { echo "ok   $1"; }
bad() { echo "FAIL $1" >&2; fail=1; }
mkdir -p "$T/root/rust/ads-rust" "$T/bin"
# a stub cargo: `test` prints a harness-shaped result; STUB_TEST_MODE plants a fault
cat >"$T/bin/cargo" <<'STUB'
#!/usr/bin/env bash
case "$1" in
  test)
    case "$(cat "$(dirname "$0")/mode" 2>/dev/null)" in
      zero) printf 'running 0 tests\n\ntest result: ok. 0 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s\n';;
      ignored) printf 'running 2 tests\ntest b ... ok\ntest a ... ignored\n\ntest result: ok. 1 passed; 0 failed; 1 ignored; 0 measured; 0 filtered out; finished in 0.00s\n';;
      failed) printf 'running 1 test\ntest b ... FAILED\n\ntest result: FAILED. 0 passed; 1 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s\n'; exit 0;;
      nores) printf 'running 1 test\ntest b ... ok\n';;
      *) printf 'running 2 tests\ntest b ... ok\ntest a ... ok\n\ntest result: ok. 2 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.%02ds\n' $((RANDOM % 90 + 10));;
    esac;;
  *) echo "stub-cargo $*";;
esac
STUB
chmod +x "$T/bin/cargo"
printf 'LC_ALL=C.UTF-8\nTZ=UTC\nTERM=xterm-256color\n' >"$T/env"
terms() { rm -rf "${T:?}/terms"; mkdir -p "$T/terms"; cp "$T/env" "$T/terms/env"; }
mkcmds() { printf '%s\n' "${@:3}" >"$T/terms/$1.cmds"; echo "$2" >"$T/terms/$1.cwd"; }
run() {
  rm -f "${T:?}/out.json"
  PATH="$T/bin:$PATH" ADS_ROOT="$T/root" ADS_TERM_DIR="$T/terms" ADS_WARM=true TERM_DEMO_TIMEOUT_S=60 "$EMIT" "$T/out.json" >"$T/so" 2>"$T/err"; rc=$?
}
refused() { # refused NAME [stderr-substring]
  run
  if [ "$rc" -ne 0 ] && [ ! -e "$T/out.json" ] && { [ -z "${2:-}" ] || grep -qF -- "$2" "$T/err"; }; then ok "$1"; else bad "$1 (rc=$rc, file=$([ -e "$T/out.json" ] && echo yes || echo no), err=$(tr '\n' ' ' <"$T/err"))"; fi
}
chk() { jq -e "$2" "$T/out.json" >/dev/null 2>&1 && ok "$1" || bad "$1"; }

# arm: one row, shared shape
terms; mkcmds aaaaaaaaaa . 'echo hello' 'echo "n=$((1+1))"'
run
if [ "$rc" -eq 0 ] && jq -e . "$T/out.json" >/dev/null 2>&1; then ok "happy-valid-json"; else bad "happy-valid-json (rc=$rc: $(cat "$T/err"))"; fi
chk "schema+course" '.schema=="demo-json/v1" and .course=="ads-c01-rust" and (.demos|length)==1'
chk "row keys" '.demos[0]|keys==["command","commands","exit","id","plots","stdout","stdout_sha256"]'
chk "id is term-<file stem>" '.demos[0].id=="term-aaaaaaaaaa"'
chk "commands is an array of strings, one per typed line" '.demos[0].commands==["echo hello","echo \"n=$((1+1))\""]'
chk "command is the file text" '.demos[0].command=="echo hello\necho \"n=$((1+1))\"\n"'
chk "exit 0, plots empty" '.demos[0]|(.exit==0 and .plots==[])'
chk "stdout is the transcript" '.demos[0].stdout|(contains("$ echo hello\nhello") and contains("n=2"))'
chk "sha256 field present" '.demos[0].stdout_sha256|test("^[0-9a-f]{64}$")'
got=$(jq -j '.demos[0].stdout' "$T/out.json" | sha256sum | cut -d' ' -f1); [ "$got" = "$(jq -r '.demos[0].stdout_sha256' "$T/out.json")" ] && ok "sha256 matches stdout" || bad "sha256 matches stdout"
# cwd sidecar: a row can start in the crate dir
terms; echo marker >"$T/root/rust/ads-rust/m.txt"; mkcmds bbbbbbbbbb rust/ads-rust 'cat m.txt'
run; chk "cwd sidecar honoured" '.demos[0].stdout|contains("marker")'
# a final line without a newline is still one array element
terms; printf '%s' 'echo ok' >"$T/terms/dddddddddd.cmds"; echo . >"$T/terms/dddddddddd.cwd"
run; chk "unterminated final line is one array element" '.demos[0].commands==["echo ok"]'
# string-only input (the legacy batch file, no .cmds) is refused: a row must come from a typed-lines file
terms; echo '01|x|ex|s.rs|1|2|echo hi|hi|a|b|n1|n2' >"$T/terms/m1.batch"; refused "no .cmds files refused" ".cmds"
# zero-line .cmds
terms; : >"$T/terms/ffffffffff.cmds"; echo . >"$T/terms/ffffffffff.cwd"; refused "empty .cmds refused" "ffffffffff"
terms; printf '\n\n' >"$T/terms/ffffffffff.cmds"; echo . >"$T/terms/ffffffffff.cwd"; refused "blank-only .cmds refused" "ffffffffff"
# duplicate ids (two files whose ids are the same after case folding)
terms; mkcmds gggggggggg . 'echo a'; cp "$T/terms/gggggggggg.cmds" "$T/terms/GGGGGGGGGG.cmds"; refused "duplicate id refused" "duplicate"
# malformed id
terms; mkcmds 'x y' . 'echo a'; refused "bad id refused" "id"
# non-zero exit
terms; mkcmds hhhhhhhhhh . 'echo partial' 'false' 'exit 3'; refused "nonzero-exit refused" "hhhhhhhhhh"
# a command with no output still shows its prompt line (the row is never empty)
terms; mkcmds iiiiiiiiii . ':'; run; chk "prompt line shown for a silent command" '.demos[0].stdout|contains("$ :")'
# command not found
terms; mkcmds jjjjjjjjjj . 'no-such-command-xyz'; refused "command not found refused" "jjjjjjjjjj"
# cargo test facts: zero passed, ignored, failed, no result line
terms; mkcmds kkkkkkkkkk . 'cargo test --locked --offline --test p9'
echo zero >"$T/bin/mode"; refused "passed==0 refused" "passed"
echo ignored >"$T/bin/mode"; refused "ignored test refused" "ignored"
echo failed >"$T/bin/mode"; refused "failed test refused" "failed"
echo nores >"$T/bin/mode"; refused "no test result line refused" "test result"
: >"$T/bin/mode"; run; [ "$rc" -eq 0 ] && ok "good test run accepted" || bad "good test run accepted (rc=$rc: $(cat "$T/err"))"
# pipefail in the session
terms; mkcmds mmmmmmmmmm . 'set -o | grep pipefail'
run; chk "pipefail is on in the session" '.demos[0].stdout|test("pipefail\\s+on")'
# determinism: two runs give the same hashes although the harness timing changes every run (the stub prints a random one)
terms; mkcmds nnnnnnnnnn . 'cargo test --locked --offline --test p1' 'echo done'
run; a=$(jq -r '.demos[0].stdout_sha256' "$T/out.json"); run; b=$(jq -r '.demos[0].stdout_sha256' "$T/out.json"); [ -n "$a" ] && [ "$a" = "$b" ] && ok "row hash stable across runs" || bad "row hash stable across runs"
# measured bench timings (`  polars: 7.8 ms`) are pinned, a rerun hashes the same
terms; mkcmds oooooooooo . 'printf "   polars: %d.%d ms\n btreemap: %d.%d ms\n" $((RANDOM%9+1)) $RANDOM $((RANDOM%9+1)) $RANDOM'
run; a=$(jq -r ".demos[0].stdout_sha256" "$T/out.json"); run; b=$(jq -r ".demos[0].stdout_sha256" "$T/out.json"); [ -n "$a" ] && [ "$a" = "$b" ] && ok "bench timing pinned" || bad "bench timing pinned"
# a stale OUT from an earlier run must not survive a refused run
terms; echo stale >"$T/out.json"; PATH="$T/bin:$PATH" ADS_ROOT="$T/root" ADS_TERM_DIR="$T/terms" ADS_WARM=true "$EMIT" "$T/out.json" >/dev/null 2>&1
[ ! -e "$T/out.json" ] && ok "stale output removed" || bad "stale output removed"
[ "$fail" -eq 0 ] && echo "falsify-emit-demo-json OK" || { echo "falsify-emit-demo-json RED" >&2; exit 1; }
