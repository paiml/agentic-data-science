#!/usr/bin/env bash
# falsify-emit-demo-json.sh: planted faults for rust/scripts/emit-demo-json.sh. Each refusal arm must exit non-zero with
# no file written, and its stderr must name exactly one error id (the arm's own) with the arm's own text, so no arm can
# pass for another reason. Accept arms check the written row. Stub commands only: no network, no real cargo.
set -uo pipefail
export LC_ALL=C
HERE="$(cd "$(dirname "$0")" && pwd)"
EMIT="$HERE/emit-demo-json.sh"
T=$(mktemp -d "${TMPDIR:-/tmp}/emit-falsify.XXXXXX"); T=$(cd "$T" && pwd -P); trap 'rm -rf "${T:?}"' EXIT
fail=0; arms=0
ok() { arms=$((arms + 1)); echo "ok   $1"; }
bad() { arms=$((arms + 1)); echo "FAIL $1" >&2; fail=1; }
mkdir -p "$T/root/rust/ads-rust/sub" "$T/bin"
# a stub cargo: `test` prints a harness-shaped result (the mode file plants a fault); `build` prints what $T/bin/build says
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
  build)
    case "$(cat "$(dirname "$0")/build" 2>/dev/null)" in
      warn) printf '   Compiling foo v0.1.0 (%s)\nwarning: unused variable: `x`\n  --> src/lib.rs:3:9\n    Finished `dev` profile [unoptimized + debuginfo] target(s) in %d.%02ds\n' "$PWD" $((RANDOM % 9)) $((RANDOM % 90 + 10)) >&2;;
      err) printf '   Compiling foo v0.1.0 (%s)\nerror[E0425]: cannot find value `y` in this scope\nerror: could not compile `foo` (lib) due to 1 previous error\n' "$PWD" >&2; exit 101;;
    esac;;
  *) echo "stub-cargo $*";;
esac
STUB
chmod +x "$T/bin/cargo"
printf 'TERM=xterm-256color\nPS1=$ \n' >"$T/env"
terms() { rm -rf "${T:?}/terms"; mkdir -p "$T/terms"; cp "$T/env" "$T/terms/env"; }
mkcmds() { printf '%s\n' "${@:3}" >"$T/terms/$1.cmds"; echo "$2" >"$T/terms/$1.cwd"; }
run() {
  rm -f "${T:?}/out.json"
  env -u CARGO_TARGET_DIR PATH="$T/bin:$PATH" ADS_ROOT="$T/root" ADS_TERM_DIR="$T/terms" ADS_WARM=true TERM_DEMO_TIMEOUT_S=${TO:-60} "$EMIT" "$T/out.json" >"$T/so" 2>"$T/err"; rc=$?
}
refused() { # refused NAME E-ID TEXT: non-zero, no file, the only error id on stderr is E-ID, and its line carries TEXT
  run
  local ids; ids=$(grep -oE '^FAIL E-[A-Z]+' "$T/err" | sort -u | tr '\n' ' ')
  if [ "$rc" -ne 0 ] && [ ! -e "$T/out.json" ] && [ "$ids" = "FAIL $2 " ] && grep -E "^FAIL $2 " "$T/err" | grep -qF -- "$3"; then ok "$1"
  else bad "$1 (rc=$rc, file=$([ -e "$T/out.json" ] && echo yes || echo no), ids=[$ids], err=$(head -c 400 "$T/err" | tr '\n' ' '))"; fi
}
accepted() { run; [ "$rc" -eq 0 ] && [ -e "$T/out.json" ] && ok "$1" || bad "$1 (rc=$rc: $(head -c 400 "$T/err" | tr '\n' ' '))"; }
chk() { jq -e "$2" "$T/out.json" >/dev/null 2>&1 && ok "$1" || bad "$1"; }
same_twice() { run; local a b; a=$(jq -r '.demos[0].stdout_sha256' "$T/out.json" 2>/dev/null); run; b=$(jq -r '.demos[0].stdout_sha256' "$T/out.json" 2>/dev/null)
  [ -n "$a" ] && [ "$a" != null ] && [ "$a" = "$b" ] && ok "$1" || bad "$1 (a=$a b=$b err=$(head -c 300 "$T/err" | tr '\n' ' '))"; }

# --- shape
terms; mkcmds aaaaaaaaaa . 'echo hello' 'echo "n=$((1+1))"'; accepted "happy run accepted"
chk "schema+course" '.schema=="demo-json/v1" and .course=="ads-c01-rust" and (.demos|length)==1'
chk "row keys" '.demos[0]|keys==["command","commands","exit","id","plots","stdout","stdout_sha256"]'
chk "id is term-<file stem>" '.demos[0].id=="term-aaaaaaaaaa"'
chk "commands is an array of strings, one per typed line" '.demos[0].commands==["echo hello","echo \"n=$((1+1))\""]'
chk "command is the file text" '.demos[0].command=="echo hello\necho \"n=$((1+1))\"\n"'
chk "exit 0, plots empty" '.demos[0]|(.exit==0 and .plots==[])'
chk "stdout is the transcript" '.demos[0].stdout|(contains("$ echo hello\nhello") and contains("n=2"))'
got=$(jq -j '.demos[0].stdout' "$T/out.json" | sha256sum | cut -d' ' -f1); [ "$got" = "$(jq -r '.demos[0].stdout_sha256' "$T/out.json")" ] && ok "sha256 matches stdout" || bad "sha256 matches stdout"
terms; echo marker >"$T/root/rust/ads-rust/m.txt"; mkcmds bbbbbbbbbb rust/ads-rust 'cat m.txt'; run; chk "cwd sidecar honoured" '.demos[0].stdout|contains("marker")'
terms; printf '%s' 'echo ok' >"$T/terms/dddddddddd.cmds"; echo . >"$T/terms/dddddddddd.cwd"; run; chk "unterminated final line is one array element" '.demos[0].commands==["echo ok"]'
terms; mkcmds iiiiiiiiii . ':'; run; chk "prompt line shown for a silent command" '.demos[0].stdout|contains("$ :")'
# --- A: session state carries from line to line, as in a terminal
terms; mkcmds cccccccccc rust/ads-rust 'cd sub' 'export V=42' 'pwd' 'echo "v=$V"'; run
chk "cd and export persist across lines" '.demos[0].stdout|contains("$ pwd\n./rust/ads-rust/sub\n$ echo \"v=$V\"\nv=42")'
terms; mkcmds mmmmmmmmmm . 'set -o | grep -E "^(errexit|pipefail)"'; run; chk "errexit and pipefail on in the session" '.demos[0].stdout|(test("errexit\\s+on") and test("pipefail\\s+on"))'
terms; mkcmds cccccccccc . 'if false; then echo no; fi' 'false || echo handled'; accepted "a handled failure (if / ||) is not a failure"
# --- A: checked status, one typed line at a time
terms; mkcmds hhhhhhhhhh . 'false; echo ok'; refused "false; echo ok refused" E-STATUS "term-hhhhhhhhhh line 1 exit 1"
grep -q '^ok$' "$T/err" && bad "false; echo ok: the session went on after the failing command" || ok "false; echo ok: the session stops at the failing command"
terms; mkcmds hhhhhhhhhh . 'false | cat'; refused "false | cat refused (left side of a pipeline counts)" E-STATUS "term-hhhhhhhhhh line 1 exit 1"
terms; mkcmds hhhhhhhhhh . 'false && echo x'; refused "line status in an errexit-exempt position refused" E-STATUS "term-hhhhhhhhhh line 1 exit 1"
terms; mkcmds hhhhhhhhhh . 'echo partial' 'false' 'echo after'; refused "status 1 refused at its line" E-STATUS "term-hhhhhhhhhh line 2 exit 1"
grep -qF '$ echo after' "$T/err" && bad "status 1: a later line ran" || ok "status 1: no later line ran"
terms; mkcmds hhhhhhhhhh . 'echo partial' "sh -c 'exit 7'" 'echo after'; refused "status 7 refused" E-STATUS "term-hhhhhhhhhh line 2 exit 7"
grep -qE '^term-hhhhhhhhhh [0-9]+ bytes exit=7$' "$T/so" && ok "recorded exit is the failing command's own status" || bad "recorded exit is the failing command's own status"
terms; mkcmds hhhhhhhhhh . 'sh -c "exit 125"'; refused "status 125 refused" E-STATUS "term-hhhhhhhhhh line 1 exit 125"
terms; mkcmds hhhhhhhhhh . 'echo a' 'echo "b' 'c"' 'sh -c "exit 3"'; refused "line number counts typed lines (a two-line command before it)" E-STATUS "line 4 exit 3"
terms; mkcmds jjjjjjjjjj . 'no-such-command-xyz'; refused "command not found refused" E-STATUS "term-jjjjjjjjjj line 1 exit 127 (not runnable)"
terms; mkcmds jjjjjjjjjj . 'echo "unclosed'; refused "unparsed final command refused" E-STATUS "term-jjjjjjjjjj line 1 exit 2"
terms; mkcmds eeeeeeeeee . 'echo a' 'exit 0' 'echo b'; refused "exit 0 before the last line refused" E-EARLY "term-eeeeeeeeee session ended at line 2"
terms; mkcmds ssssssssss . 'sleep 5'; TO=1 refused "timeout refused" E-TIMEOUT "term-ssssssssss session timed out after 1s"
# --- B: locale
terms; mkcmds aaaaaaaaaa . 'echo a'; mkcmds Bbbbbbbbbb . 'echo b'
uloc=$(locale -a 2>/dev/null | grep -iE '^en_US\.utf-?8$' | head -n 1); uloc=${uloc:-C.UTF-8}
LC_ALL=$uloc LANG=$uloc refused "uppercase id refused under a UTF-8 caller locale ($uloc)" E-ID "'Bbbbbbbbbb'"
terms; mkcmds aaaaaaaaaa . 'echo "$LC_ALL $TZ"'; LC_ALL=$uloc TZ=America/New_York run; chk "rows run under LC_ALL=C TZ=UTC whatever the caller's" '.demos[0].stdout|contains("\nC UTC\n")'
terms; mkcmds aaaaaaaaaa . 'echo a'; echo 'LC_ALL=C.UTF-8' >>"$T/terms/env"; refused "env file may not set the locale" E-ENV "LC_ALL"
# --- input guards
terms; echo '01|x|ex|s.rs|1|2|echo hi|hi|a|b|n1|n2' >"$T/terms/m1.batch"; refused "no .cmds files refused" E-INPUT ".cmds"
terms; : >"$T/terms/ffffffffff.cmds"; refused "empty .cmds refused" E-EMPTY "term-ffffffffff"
terms; printf '\n\n' >"$T/terms/ffffffffff.cmds"; refused "blank-only .cmds refused" E-EMPTY "term-ffffffffff"
terms; mkcmds 'x y' . 'echo a'; refused "bad id refused" E-ID "'x y'"
terms; mkcmds gggggggggg ../.. 'echo a'; refused "cwd outside the root refused" E-CWD "term-gggggggggg"
# --- cargo test facts
terms; mkcmds kkkkkkkkkk . 'cargo test --locked --offline --test p9'
echo zero >"$T/bin/mode"; refused "passed==0 refused" E-TESTS "passed == 0"
echo ignored >"$T/bin/mode"; refused "ignored test refused" E-TESTS "1 ignored"
echo failed >"$T/bin/mode"; refused "failed test refused" E-TESTS "1 failed"
echo nores >"$T/bin/mode"; refused "no test result line refused" E-TESTS "no test result line"
: >"$T/bin/mode"; accepted "good test run accepted"
# --- C: normalisation N1..N3
terms; mkcmds nnnnnnnnnn . 'cargo test --locked --offline --test p1' 'echo done'; same_twice "harness duration pinned (in N.NNs)"
terms; mkcmds oooooooooo . 'printf "   polars: %d.%d ms\n btreemap: %d.%d ms\n" $((RANDOM%9+1)) $RANDOM $((RANDOM%9+1)) $RANDOM'; same_twice "bench timing pinned"
terms; mkcmds qqqqqqqqqq . 'printf "commit=%s\n" $(date +%s%N | sha1sum | cut -c1-40)'; same_twice "commit id pinned"
chk "commit id replaced by zeros" '.demos[0].stdout|contains("commit=0000000000000000000000000000000000000000")'
terms; echo warn >"$T/bin/build"; mkcmds wwwwwwwwww . 'cargo build'; run
chk "warning line kept, progress line dropped, duration pinned" '.demos[0].stdout|(contains("warning: unused variable: `x`\n  --> src/lib.rs:3:9\n") and (contains("Compiling")|not) and contains("target(s) in 0.00s"))'
terms; echo err >"$T/bin/build"; mkcmds wwwwwwwwww . 'cargo build'; refused "compile error refused" E-STATUS "term-wwwwwwwwww line 1 exit 101"
grep -qF 'error[E0425]: cannot find value `y` in this scope' "$T/err" && ok "compile error line kept (shown on refusal)" || bad "compile error line kept (shown on refusal)"
: >"$T/bin/build"
terms; mkcmds xxxxxxxxxx . 'echo "Compiling is fun"' 'echo "    Compiling x"'; run
chk "progress rule is exact (12-column status form only)" '.demos[0].stdout|(contains("\nCompiling is fun\n") and contains("\n    Compiling x\n"))'
tg='printf "     Running tests/p1.rs (%s/llvm-cov-target/debug/deps/p1-%s)\n     Running unittests examples/a-m1-p1/main.rs (%s/llvm-cov-target/debug/examples/a_m1_p1-%s)\n" "$CARGO_TARGET_DIR" $(date +%s%N | sha1sum | cut -c1-16) "$CARGO_TARGET_DIR" $(date +%s%N | sha1sum | cut -c25-40)'
terms; mkcmds rrrrrrrrrr . "$tg" 'pwd'
run2() { rm -f "${T:?}/out.json"; env -u CARGO_TARGET_DIR PATH="$T/bin:$PATH" ADS_ROOT="$1" ADS_TERM_DIR="$T/terms" ADS_WARM=true ${2:+"CARGO_TARGET_DIR=$2"} "$EMIT" "$T/out.json" >"$T/so" 2>"$T/err"; }
run2 "$T/root" "$T/tgt1"; a=$(jq -r '.demos[0].stdout_sha256' "$T/out.json" 2>/dev/null)
chk "llvm-cov-target hashes and the target root pinned" '.demos[0].stdout|contains("(target/llvm-cov-target/debug/deps/p1-0000000000000000)\n") and contains("(target/llvm-cov-target/debug/examples/a_m1_p1-0000000000000000)\n$ pwd\n.\n")'
mkdir -p "$T/root2/rust/ads-rust"; ln -s "$T/root2" "$T/link2"; run2 "$T/link2" "$T/other/tgt2"; b=$(jq -r '.demos[0].stdout_sha256' "$T/out.json" 2>/dev/null)
[ -n "$a" ] && [ "$a" != null ] && [ "$a" = "$b" ] && ok "row hash independent of repo root (symlinked too) and target dir" || bad "row hash independent of repo root and target dir (a=$a b=$b $(head -c 300 "$T/err"))"
run2 "$T/root" ""; chk "default target dir (under the root) is the target token, not ./rust/ads-rust/target" '.demos[0].stdout|contains("(target/llvm-cov-target/debug/deps/p1-0000000000000000)\n")'
terms; mkcmds pppppppppp . 'git config --get-all safe.directory'; run; chk "row git trusts exactly the repo root" '.demos[0].stdout|contains("$ git config --get-all safe.directory\n.\n")'
# --- C: refusal scan N4
terms; mkcmds llllllllll . 'echo "cache at /tmp/build-x/out.bin"'; refused "surviving /tmp path refused" E-LEAK "term-llllllllll line 1: absolute path"
terms; mkcmds llllllllll . 'echo "/home/1001/src/x.rs:3"'; refused "surviving /home path refused" E-LEAK "absolute path"
terms; mkcmds llllllllll . 'echo "home is $HOME"'; refused "the row's own HOME (emitter work dir) refused" E-LEAK "host path"
terms; mkcmds llllllllll . 'echo "deps: $CARGO_HOME/registry/src"'; CARGO_HOME="$T/ch" refused "CARGO_HOME path refused" E-LEAK "host path"
terms; mkcmds llllllllll . 'echo "rev 0123456789abcdef0123456789abcdef01234567"'; refused "40-hex outside commit= refused" E-LEAK "volatile 40-hex"
terms; mkcmds llllllllll . 'echo "build/out-0123456789abcdef"'; refused "16-hex outside target/ refused" E-LEAK "volatile 16-hex"
terms; mkcmds llllllllll . 'echo "see /usr/share/doc and ./rust/x"'; accepted "a system path and a root-relative path are not refused"
terms; mkcmds llllllllll . 'echo "accuracy: 0.9764705882352941 diff = 8.526512829121202e-13"'; accepted "a float's fraction digits are not a 16-hex token"
# --- stale output
terms; echo stale >"$T/out.json"; PATH="$T/bin:$PATH" ADS_ROOT="$T/root" ADS_TERM_DIR="$T/terms" ADS_WARM=true "$EMIT" "$T/out.json" >/dev/null 2>&1
[ ! -e "$T/out.json" ] && ok "stale output removed" || bad "stale output removed"
grep -qE '^\s*CARGO_TERM_QUIET' "$HERE/../term-demos/env" && bad "term-demos/env must not set CARGO_TERM_QUIET" || ok "env does not set CARGO_TERM_QUIET"
[ "$fail" -eq 0 ] && echo "falsify-emit-demo-json OK ($arms arms)" || { echo "falsify-emit-demo-json RED ($arms arms)" >&2; exit 1; }
