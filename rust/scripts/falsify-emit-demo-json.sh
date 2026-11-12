#!/usr/bin/env bash
# falsify-emit-demo-json.sh: planted faults for rust/scripts/emit-demo-json.sh. Each refusal arm must exit non-zero with
# no file written, and its stderr must name exactly one error id (the arm's own) with the arm's own text, so no arm can
# pass for another reason. Accept arms check the written row. Stub commands only: no network, no real cargo.
# A typed line may only start with a word from the emitter's closed list (bat, cargo), so the stubs are `bat` and `cargo`:
# the stub cargo's own subcommands (say, status, sleep, ...) give the arms the outputs and statuses they need.
# The set of error ids is read from the emitter itself; the run is red if an id the emitter can emit has no refusal arm.
set -uo pipefail
export LC_ALL=C
HERE="$(cd "$(dirname "$0")" && pwd)"
EMIT="$HERE/emit-demo-json.sh"
T=$(mktemp -d "${TMPDIR:-/tmp}/emit-falsify.XXXXXX"); T=$(cd "$T" && pwd -P); trap 'rm -rf "${T:?}"' EXIT
fail=0; arms=0
ok() { arms=$((arms + 1)); echo "ok   $1"; }
bad() { arms=$((arms + 1)); echo "FAIL $1" >&2; fail=1; }
mkdir -p "$T/root/rust/ads-rust/sub" "$T/bin"
: >"$T/covered"
# a stub cargo: `test` prints a harness-shaped result (the mode file plants a fault); `build` prints what $T/bin/build says;
# the other subcommands print a fixed or a changing value, or end with a chosen status
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
  say) shift; echo "$*";;
  status) exit "$2";;
  sleep) sleep "$2";;
  killsession) kill -9 "$PPID";;
  pwd) pwd;;
  cat) cat "$2";;
  git) shift; exec git "$@";;
  printenv) shift; v=(); for n in "$@"; do v+=("${!n-}"); done; echo "${v[*]}";;
  progress) printf 'Compiling is fun\n    Compiling x\n';;
  bench) printf '   polars: %d.%d ms\n btreemap: %d.%d ms\n' $((RANDOM % 9 + 1)) $RANDOM $((RANDOM % 9 + 1)) $RANDOM;;
  commitid) printf 'commit=%s\n' "$(date +%s%N | sha1sum | cut -c1-40)";;
  tgline) printf '     Running tests/p1.rs (%s/llvm-cov-target/debug/deps/p1-%s)\n     Running unittests examples/a-m1-p1/main.rs (%s/llvm-cov-target/debug/examples/a_m1_p1-%s)\n' "$CARGO_TARGET_DIR" "$(date +%s%N | sha1sum | cut -c1-16)" "$CARGO_TARGET_DIR" "$(date +%s%N | sha1sum | cut -c25-40)";;
  *) echo "stub-cargo $*";;
esac
STUB
cat >"$T/bin/bat" <<'STUB'
#!/usr/bin/env bash
echo "stub-bat $*"
STUB
# a stub `script` that loses the first line of the transcript when the drop file exists (a transcript fault)
cat >"$T/bin/script" <<'STUB'
#!/usr/bin/env bash
real=$(PATH=/usr/bin:/bin command -v script)
if [ -e "$(dirname "$0")/script-drop" ]; then "$real" "$@" | sed 1d; else exec "$real" "$@"; fi
STUB
chmod +x "$T/bin/cargo" "$T/bin/bat" "$T/bin/script"
# GIT_PAGER/PAGER as in the committed env file: a row's git must never open a pager on the pty
printf 'TERM=xterm-256color\nPS1=$ \nGIT_PAGER=cat\nPAGER=cat\n' >"$T/env"
Z64=0000000000000000000000000000000000000000000000000000000000000000
terms() { rm -rf "${T:?}/terms"; mkdir -p "$T/terms"; cp "$T/env" "$T/terms/env"; : >"$T/terms/rows.list"; }
sha() { sha256sum <"$1" | cut -d' ' -f1; }
pinrow() { echo "$1 $(sha "$T/terms/$1.cmds") $(sha "$T/terms/$1.cwd")" >>"$T/terms/rows.list"; }
mkcmds() { printf '%s\n' "${@:3}" >"$T/terms/$1.cmds"; echo "$2" >"$T/terms/$1.cwd"; pinrow "$1"; }
run() {
  rm -f "${T:?}/out.json"
  env -u CARGO_TARGET_DIR PATH="${EMIT_PATH:-$T/bin:$PATH}" ADS_ROOT="$T/root" ADS_TERM_DIR="$T/terms" ADS_WARM=${WARM:-true} TERM_DEMO_TIMEOUT_S=${TO:-60} ${EMIT_SH:-} "$EMIT" "$T/out.json" >"$T/so" 2>"$T/err"; rc=$?
}
refused() { # refused NAME E-ID TEXT: non-zero, no file, the only error id on stderr is E-ID, and its line carries TEXT
  run
  local ids; ids=$(grep -oE '^FAIL E-[A-Z]+' "$T/err" | sort -u | tr '\n' ' ')
  if [ "$rc" -ne 0 ] && [ ! -e "$T/out.json" ] && [ "$ids" = "FAIL $2 " ] && grep -E "^FAIL $2 " "$T/err" | grep -qF -- "$3"; then ok "$1"; echo "$2" >>"$T/covered"
  else bad "$1 (rc=$rc, file=$([ -e "$T/out.json" ] && echo yes || echo no), ids=[$ids], err=$(head -c 400 "$T/err" | tr '\n' ' '))"; fi
}
accepted() { run; [ "$rc" -eq 0 ] && [ -e "$T/out.json" ] && ok "$1" || bad "$1 (rc=$rc: $(head -c 400 "$T/err" | tr '\n' ' '))"; }
chk() { jq -e "$2" "$T/out.json" >/dev/null 2>&1 && ok "$1" || bad "$1"; }
same_twice() { run; local a b; a=$(jq -r '.demos[0].stdout_sha256' "$T/out.json" 2>/dev/null); run; b=$(jq -r '.demos[0].stdout_sha256' "$T/out.json" 2>/dev/null)
  [ -n "$a" ] && [ "$a" != null ] && [ "$a" = "$b" ] && ok "$1" || bad "$1 (a=$a b=$b err=$(head -c 300 "$T/err" | tr '\n' ' '))"; }
form() { # form NAME LINE...: a typed line outside the closed command form is refused before anything runs, by file and line
  local name=$1 want=$2; shift 2
  terms; mkcmds hhhhhhhhhh . "$@"; refused "$name" E-FORM "hhhhhhhhhh.cmds:$want"
}
formtext() { # formtext NAME TEXT LINE...: as form, and the refusal names its reason
  local name=$1 text=$2; shift 2
  terms; mkcmds hhhhhhhhhh . "$@"; refused "$name" E-FORM "hhhhhhhhhh.cmds:1 $text"
}

# --- shape
terms; mkcmds aaaaaaaaaa . 'cargo say hello' 'cargo say n=2'; accepted "happy run accepted"
chk "schema+course" '.schema=="demo-json/v1" and .course=="ads-c01-rust" and (.demos|length)==1'
chk "row keys" '.demos[0]|keys==["command","commands","exit","id","plots","stdout","stdout_sha256"]'
chk "id is term-<file stem>" '.demos[0].id=="term-aaaaaaaaaa"'
chk "commands is an array of strings, one per typed line" '.demos[0].commands==["cargo say hello","cargo say n=2"]'
chk "command is the file text" '.demos[0].command=="cargo say hello\ncargo say n=2\n"'
chk "exit 0, plots empty" '.demos[0]|(.exit==0 and .plots==[])'
chk "stdout is the transcript" '.demos[0].stdout|(contains("$ cargo say hello\nhello") and contains("n=2"))'
got=$(jq -j '.demos[0].stdout' "$T/out.json" | sha256sum | cut -d' ' -f1); [ "$got" = "$(jq -r '.demos[0].stdout_sha256' "$T/out.json")" ] && ok "sha256 matches stdout" || bad "sha256 matches stdout"
terms; echo marker >"$T/root/rust/ads-rust/m.txt"; mkcmds bbbbbbbbbb rust/ads-rust 'cargo cat m.txt'; run; chk "cwd sidecar honoured" '.demos[0].stdout|contains("marker")'
terms; printf '%s' 'cargo say ok' >"$T/terms/dddddddddd.cmds"; echo . >"$T/terms/dddddddddd.cwd"; pinrow dddddddddd; run; chk "unterminated final line is one array element" '.demos[0].commands==["cargo say ok"]'
terms; mkcmds iiiiiiiiii . 'cargo status 0'; run; chk "prompt line shown for a silent command" '.demos[0].stdout|contains("$ cargo status 0")'
# --- A: checked status, one typed line at a time
terms; mkcmds hhhhhhhhhh . 'cargo status 1'; refused "status 1 refused at its line" E-STATUS "term-hhhhhhhhhh line 1 exit 1"
terms; mkcmds hhhhhhhhhh . 'cargo say partial' 'cargo status 1' 'cargo say after'; refused "status 1 on a later line refused at its line" E-STATUS "term-hhhhhhhhhh line 2 exit 1"
grep -qF '$ cargo say after' "$T/err" && bad "status 1: a later line ran" || ok "status 1: no later line ran"
terms; mkcmds hhhhhhhhhh . 'cargo say partial' 'cargo status 7' 'cargo say after'; refused "status 7 refused" E-STATUS "term-hhhhhhhhhh line 2 exit 7"
grep -qE '^term-hhhhhhhhhh [0-9]+ bytes exit=7$' "$T/so" && ok "recorded exit is the failing command's own status" || bad "recorded exit is the failing command's own status"
terms; mkcmds hhhhhhhhhh . 'cargo status 125'; refused "status 125 refused" E-STATUS "term-hhhhhhhhhh line 1 exit 125"
terms; mkcmds hhhhhhhhhh . 'cargo say a' 'cargo say b' 'cargo say c' 'cargo status 3'; refused "line number counts typed lines" E-STATUS "line 4 exit 3"
terms; mkcmds jjjjjjjjjj . 'cargo status 127'; refused "status 127 refused as not runnable" E-STATUS "term-jjjjjjjjjj line 1 exit 127 (not runnable)"
terms; mkcmds ssssssssss . 'cargo sleep 5'; TO=1 refused "timeout refused" E-TIMEOUT "term-ssssssssss session timed out after 1s"
terms; mkcmds kkkkkkkkkk . 'cargo say before' 'cargo killsession'; refused "session killed before its end record refused" E-NOSTATUS "term-kkkkkkkkkk no status record"
terms; mkcmds tttttttttt . 'cargo say one' 'cargo say two'; : >"$T/bin/script-drop"; refused "a command missing from the transcript refused" E-TRANSCRIPT "term-tttttttttt missing: \$ cargo say one"
rm -f "$T/bin/script-drop"
# --- A: the closed command form (allow-list: alphabet, single spaces, first word from the closed list; checked before anything runs)
form "command substitution refused" 1 'echo $(false)'
form "command substitution with a list refused" 1 'x=$(false; echo ok)'
form "backtick refused" 1 'echo `false`'
form "arithmetic expansion refused" 1 'echo "$((1+1))"'
form "and-list then a command refused" 1 'false && echo x; echo ok'
form "and-list refused" 1 'false && echo x'
form "or-list refused" 1 'false || echo x'
form "semicolon list refused" 1 'false; echo ok'
form "background job refused" 1 'false &'
form "pipe refused" 1 'false | cat'
form "leading set refused" 1 'set +e'
form "leading exec refused" 1 'exec true'
form "leading eval refused" 1 'eval false'
form "leading trap refused" 1 'trap - EXIT'
form "leading exit refused (the session cannot end early)" 2 'cargo say a' 'exit 0' 'cargo say b'
form "subshell refused" 1 '(false; echo ok)'
form "brace group refused" 1 '{ false; }'
form "fd 2 redirected to null refused" 1 'echo hi 2>/dev/null'
form "trailing backslash refused" 1 'echo a \'
form "compound command word refused" 1 'if false'
form "here-document refused" 1 'cat <<EOF'
form "every offending line is named, by line" 3 'cargo say ok' 'cargo say ok' 'false &'
grep -qF 'hhhhhhhhhh.cmds:3' "$T/err" && ! grep -qE 'hhhhhhhhhh.cmds:[12] ' "$T/err" && ok "only the offending line is named" || bad "only the offending line is named"
terms; mkcmds hhhhhhhhhh . 'echo "a;b"'; refused "a quoted semicolon is outside the closed form too" E-FORM "hhhhhhhhhh.cmds:1"
terms; mkcmds hhhhhhhhhh . 'cargo say ok' 'cargo say line two' 'bat -r 23:23 -r 44:51 file.rs' 'cargo run -q --locked --offline --example a-m3-p3-tree'; accepted "plain words and options are in the closed form"
# AL-01..AL-07: known bypasses of a deny-list form check, verbatim
form "AL-01 env prefix before eval with ANSI-C quoting refused" 1 "A=1 eval \$'set +e\\nfalse\\necho ok'"
form "AL-02 quoted eval refused" 1 "\"eval\" \$'set +e\\nfalse\\necho ok'"
form "AL-03 backslash-escaped eval refused" 1 "\\eval \$'false \\x26\\x26 echo x\\x3b echo ok'"
form "AL-04 quoted set then a quoted multi-line eval refused" 1 '"set" +e' '"eval" "false' 'echo ok"'
form "AL-05 trap spoofing the status record refused" 1 "\"trap\" \$'printf \"end 0\\\\n\" > \"\$__st\"\\n\"exit\" 0' EXIT" 'false'
form "AL-06 sh -c with ANSI-C quoting refused" 1 "sh -c \$'false\\necho ok'"
form "AL-07 legacy arithmetic and fd read-write redirection refused" 1 'echo $[1+1] 2<>/dev/null'
# AL-08..AL-27: one arm per forbidden byte class or spacing fault, each with its own reason
formtext "AL-08 double quote refused" "byte 0x22" 'cargo say "x"'
formtext "AL-09 single quote refused" "byte 0x27" "cargo say 'x'"
formtext "AL-10 dollar refused" "byte 0x24" 'cargo say $HOME'
formtext "AL-11 backslash refused" "byte 0x5c" 'cargo say a\b'
formtext "AL-12 semicolon refused" "byte 0x3b" 'cargo say a;b'
formtext "AL-13 pipe refused" "byte 0x7c" 'cargo say a|b'
formtext "AL-14 ampersand refused" "byte 0x26" 'cargo say a&b'
formtext "AL-15 output redirect refused" "byte 0x3e" 'cargo say a>b'
formtext "AL-16 input redirect refused" "byte 0x3c" 'cargo say a<b'
formtext "AL-17 backtick refused" "byte 0x60" 'cargo say a`b'
formtext "AL-18 parenthesis refused" "byte 0x28" 'cargo say a(b'
formtext "AL-19 tab refused" "byte 0x09" $'cargo say\ta'
formtext "AL-20 carriage return refused" "byte 0x0d" $'cargo say a\r'
formtext "AL-21 glob star refused" "byte 0x2a" 'cargo say *'
formtext "AL-22 glob question mark refused" "byte 0x3f" 'cargo say a?'
formtext "AL-23 glob bracket refused" "byte 0x5b" 'cargo say [ab]'
formtext "AL-24 tilde refused" "byte 0x7e" 'cargo say ~'
formtext "AL-25 hash refused" "byte 0x23" 'cargo say a #b'
formtext "AL-26 non-ASCII refused" "byte 0xc3" $'cargo say caf\xc3\xa9'
formtext "AL-27 brace refused" "byte 0x7b" 'cargo say {a,b}'
formtext "AL-28 double space refused" "not words joined by single spaces" 'cargo  say a'
formtext "AL-29 leading space refused" "not words joined by single spaces" ' cargo say a'
formtext "AL-30 trailing space refused" "not words joined by single spaces" 'cargo say a '
form "AL-31 empty line between commands refused (a newline cannot sit inside a word)" 2 'cargo say a' '' 'cargo say b'
terms; printf 'cargo\0say a\n' >"$T/terms/hhhhhhhhhh.cmds"; echo . >"$T/terms/hhhhhhhhhh.cwd"; pinrow hhhhhhhhhh; refused "AL-32 NUL byte refused" E-FORM "hhhhhhhhhh.cmds:1 byte 0x00"
# AL-33..AL-36: the first word
formtext "AL-33 first word not in the closed list refused" "first word 'echo' is not in the closed list" 'echo hi'
for w in eval sh bash env xargs sudo exec command builtin source; do
  formtext "AL-34 first word '$w' refused" "first word '$w' is not in the closed list" "$w cargo say x"
done
formtext "AL-35 first word with = (env assignment prefix) refused" "first word 'A=1' is an assignment" 'A=1 cargo say x'
formtext "AL-36 first word = alone refused" "first word '=' is an assignment" '= cargo'
terms; mkcmds hhhhhhhhhh . 'cargo say a=b,c:d+e/f.g_h-i'; accepted "AL-37 = and the other alphabet bytes are accepted after the first word"
chk "AL-37 the line runs as its words" '.demos[0].stdout|contains("\na=b,c:d+e/f.g_h-i\n")'
# --- B: locale
terms; mkcmds aaaaaaaaaa . 'cargo say a'; mkcmds Bbbbbbbbbb . 'cargo say b'
uloc=$(locale -a 2>/dev/null | grep -iE '^en_US\.utf-?8$' | head -n 1); uloc=${uloc:-C.UTF-8}
LC_ALL=$uloc LANG=$uloc refused "uppercase id refused under a UTF-8 caller locale ($uloc)" E-ID "'Bbbbbbbbbb'"
terms; mkcmds aaaaaaaaaa . 'cargo printenv LC_ALL TZ'; LC_ALL=$uloc TZ=America/New_York run; chk "rows run under LC_ALL=C TZ=UTC whatever the caller's" '.demos[0].stdout|contains("\nC UTC\n")'
terms; mkcmds aaaaaaaaaa . 'cargo say a'; echo 'LC_ALL=C.UTF-8' >>"$T/terms/env"; refused "env file may not set the locale" E-ENV "LC_ALL"
# --- input guards
terms; echo '01|x|ex|s.rs|1|2|echo hi|hi|a|b|n1|n2' >"$T/terms/m1.batch"; refused "no .cmds files refused" E-INPUT ".cmds"
terms; : >"$T/terms/ffffffffff.cmds"; echo . >"$T/terms/ffffffffff.cwd"; pinrow ffffffffff; refused "empty .cmds refused" E-EMPTY "term-ffffffffff"
terms; printf '\n\n' >"$T/terms/ffffffffff.cmds"; echo . >"$T/terms/ffffffffff.cwd"; pinrow ffffffffff; refused "blank-only .cmds refused" E-EMPTY "term-ffffffffff"
terms; mkcmds 'x y' . 'cargo say a'; refused "bad id refused" E-ID "'x y'"
terms; mkcmds gggggggggg ../.. 'cargo say a'; refused "cwd outside the root refused" E-CWD "term-gggggggggg"
terms; mkcmds aaaaaaaaaa . 'cargo say a'; WARM=false refused "failing warm-up refused" E-WARM "warm-up failed"
terms; mkcmds aaaaaaaaaa . 'cargo say a'; mkdir -p "$T/nojq"; for t in bash perl script timeout sha256sum; do ln -sf "$(command -v "$t")" "$T/nojq/$t"; done
EMIT_PATH="$T/nojq" EMIT_SH="$(command -v bash)" refused "missing tool refused" E-TOOL "jq not on PATH"
# --- the declared, pinned row list (rust/term-demos/rows.list) against the row files
terms; mkcmds aaaaaaaaaa . 'cargo say a'; echo "bbbbbbbbbb $Z64 $Z64" >>"$T/terms/rows.list"; refused "a declared row without a .cmds file refused" E-ROWS "declared but has no .cmds: bbbbbbbbbb"
terms; mkcmds aaaaaaaaaa . 'cargo say a'; printf '%s\n' 'cargo say b' >"$T/terms/bbbbbbbbbb.cmds"; echo . >"$T/terms/bbbbbbbbbb.cwd"; refused "a .cmds file that is not declared refused" E-ROWS "not declared: bbbbbbbbbb.cmds"
terms; mkcmds aaaaaaaaaa . 'cargo say a'; pinrow aaaaaaaaaa; refused "a duplicate declaration refused" E-ROWS "declared twice: aaaaaaaaaa"
terms; mkcmds aaaaaaaaaa . 'cargo say a'; rm "$T/terms/rows.list"; refused "no row list refused" E-ROWS "no row list"
terms; mkcmds aaaaaaaaaa . 'cargo say a'; mkcmds cccccccccc . 'cargo say c'; accepted "declared rows equal to the .cmds files accepted"
chk "emitted count equals the declared count" '(.demos|length)==2'
# AL-38..AL-44: the pins
terms; mkcmds aaaaaaaaaa . 'cargo say a'; echo 'cargo say changed' >>"$T/terms/aaaaaaaaaa.cmds"; refused "AL-38 a .cmds changed after its pin refused" E-ROWS "pin mismatch: aaaaaaaaaa.cmds"
terms; mkcmds aaaaaaaaaa . 'cargo say a'; mkdir -p "$T/root/rust"; echo rust >"$T/terms/aaaaaaaaaa.cwd"; refused "AL-39 a .cwd changed after its pin refused" E-ROWS "pin mismatch: aaaaaaaaaa.cwd"
terms; mkcmds aaaaaaaaaa . 'cargo say a'; echo . >"$T/terms/zzzzzzzzzz.cwd"; refused "AL-40 an unlisted .cwd file refused" E-ROWS "not declared: zzzzzzzzzz.cwd"
terms; mkcmds aaaaaaaaaa . 'cargo say a'; rm "$T/terms/aaaaaaaaaa.cwd"; refused "AL-41 a listed row whose .cwd is missing refused" E-ROWS "declared but has no .cwd: aaaaaaaaaa"
terms; mkcmds aaaaaaaaaa . 'cargo say a'; rm "$T/terms/aaaaaaaaaa.cmds"; mkcmds cccccccccc . 'cargo say c'; refused "AL-42 a listed row whose .cmds is missing refused" E-ROWS "declared but has no .cmds: aaaaaaaaaa"
terms; printf '%s\n' 'cargo say a' >"$T/terms/aaaaaaaaaa.cmds"; echo . >"$T/terms/aaaaaaaaaa.cwd"; echo aaaaaaaaaa >"$T/terms/rows.list"; refused "AL-43 a row line without its two pins refused" E-ROWS "malformed line 1"
terms; mkcmds aaaaaaaaaa . 'cargo say a'; sed -i 's/ \([0-9a-f]*\)$/ \U\1/' "$T/terms/rows.list"; refused "AL-44 an upper-case pin is not a pin" E-ROWS "malformed line 1"
# --- cargo test facts
terms; mkcmds kkkkkkkkkk . 'cargo test --locked --offline --test p9'
echo zero >"$T/bin/mode"; refused "passed==0 refused" E-TESTS "passed == 0"
echo ignored >"$T/bin/mode"; refused "ignored test refused" E-TESTS "1 ignored"
echo failed >"$T/bin/mode"; refused "failed test refused" E-TESTS "1 failed"
echo nores >"$T/bin/mode"; refused "no test result line refused" E-TESTS "no test result line"
: >"$T/bin/mode"; accepted "good test run accepted"
# --- C: normalisation N1..N3
terms; mkcmds nnnnnnnnnn . 'cargo test --locked --offline --test p1' 'cargo say done'; same_twice "harness duration pinned (in N.NNs)"
terms; mkcmds oooooooooo . 'cargo bench'; same_twice "bench timing pinned"
terms; mkcmds qqqqqqqqqq . 'cargo commitid'; same_twice "commit id pinned"
chk "commit id replaced by zeros" '.demos[0].stdout|contains("commit=0000000000000000000000000000000000000000")'
terms; echo warn >"$T/bin/build"; mkcmds wwwwwwwwww . 'cargo build'; run
chk "warning line kept, progress line dropped, duration pinned" '.demos[0].stdout|(contains("warning: unused variable: `x`\n  --> src/lib.rs:3:9\n") and (contains("Compiling")|not) and contains("target(s) in 0.00s"))'
terms; echo err >"$T/bin/build"; mkcmds wwwwwwwwww . 'cargo build'; refused "compile error refused" E-STATUS "term-wwwwwwwwww line 1 exit 101"
grep -qF 'error[E0425]: cannot find value `y` in this scope' "$T/err" && ok "compile error line kept (shown on refusal)" || bad "compile error line kept (shown on refusal)"
: >"$T/bin/build"
terms; mkcmds xxxxxxxxxx . 'cargo progress'; run
chk "progress rule is exact (12-column status form only)" '.demos[0].stdout|(contains("\nCompiling is fun\n") and contains("\n    Compiling x\n"))'
terms; mkcmds rrrrrrrrrr . 'cargo tgline' 'cargo pwd'
run2() { rm -f "${T:?}/out.json"; env -u CARGO_TARGET_DIR PATH="$T/bin:$PATH" ADS_ROOT="$1" ADS_TERM_DIR="$T/terms" ADS_WARM=true ${2:+"CARGO_TARGET_DIR=$2"} "$EMIT" "$T/out.json" >"$T/so" 2>"$T/err"; }
run2 "$T/root" "$T/tgt1"; a=$(jq -r '.demos[0].stdout_sha256' "$T/out.json" 2>/dev/null)
chk "llvm-cov-target hashes and the target root pinned" '.demos[0].stdout|contains("(target/llvm-cov-target/debug/deps/p1-0000000000000000)\n") and contains("(target/llvm-cov-target/debug/examples/a_m1_p1-0000000000000000)\n$ cargo pwd\n.\n")'
mkdir -p "$T/root2/rust/ads-rust"; ln -s "$T/root2" "$T/link2"; run2 "$T/link2" "$T/other/tgt2"; b=$(jq -r '.demos[0].stdout_sha256' "$T/out.json" 2>/dev/null)
[ -n "$a" ] && [ "$a" != null ] && [ "$a" = "$b" ] && ok "row hash independent of repo root (symlinked too) and target dir" || bad "row hash independent of repo root and target dir (a=$a b=$b $(head -c 300 "$T/err"))"
run2 "$T/root" "$T/tgt1/"; c=$(jq -r '.demos[0].stdout_sha256' "$T/out.json" 2>/dev/null)
chk "a trailing slash on the target dir still pins the target token" '.demos[0].stdout|contains("(target/llvm-cov-target/debug/deps/p1-0000000000000000)\n")'
[ -n "$a" ] && [ "$a" = "$c" ] && ok "row hash independent of a trailing slash on the target dir" || bad "row hash independent of a trailing slash on the target dir (a=$a c=$c)"
run2 "$T/root" "$T/tgt1//"; d=$(jq -r '.demos[0].stdout_sha256' "$T/out.json" 2>/dev/null)
[ -n "$a" ] && [ "$a" = "$d" ] && ok "row hash independent of a double trailing slash" || bad "row hash independent of a double trailing slash (a=$a d=$d)"
run2 "$T/root" ""; chk "default target dir (under the root) is the target token, not ./rust/ads-rust/target" '.demos[0].stdout|contains("(target/llvm-cov-target/debug/deps/p1-0000000000000000)\n")'
terms; mkcmds pppppppppp . 'cargo git config --get-all safe.directory'; TO=20 run; chk "row git trusts exactly the repo root" '.demos[0].stdout|contains("$ cargo git config --get-all safe.directory\n.\n")'
# AL-45: git in a row reads no system and no global config file (and does not page)
terms; mkcmds pppppppppp . 'cargo printenv GIT_CONFIG_NOSYSTEM GIT_CONFIG_GLOBAL'; run; chk "AL-45 row git: GIT_CONFIG_NOSYSTEM=1, GIT_CONFIG_GLOBAL=/dev/null" '.demos[0].stdout|contains("\n1 /dev/null\n")'
terms; mkcmds pppppppppp . 'cargo git config --list --show-origin'; TO=20 run; chk "AL-46 row git sees command-line config only" '.demos[0].stdout|(contains("command line:") and (test("\nfile:")|not))'
# --- C: refusal scan N4
terms; mkcmds llllllllll . 'cargo say cache at /tmp/build-x/out.bin'; refused "surviving /tmp path refused" E-LEAK "term-llllllllll line 1: absolute path"
terms; mkcmds llllllllll . 'cargo say /home/1001/src/x.rs:3'; refused "surviving /home path refused" E-LEAK "absolute path"
terms; mkcmds llllllllll . 'cargo printenv HOME'; refused "the row's own HOME (emitter work dir) refused" E-LEAK "host path"
terms; mkcmds llllllllll . 'cargo printenv CARGO_HOME'; CARGO_HOME="$T/ch" refused "CARGO_HOME path refused" E-LEAK "host path"
terms; mkcmds llllllllll . 'cargo say rev 0123456789abcdef0123456789abcdef01234567'; refused "40-hex outside commit= refused" E-LEAK "volatile hex run"
terms; mkcmds llllllllll . 'cargo say build/out-0123456789abcdef'; refused "16-hex outside target/ refused" E-LEAK "volatile hex run"
terms; mkcmds llllllllll . 'cargo say p1.0123456789abcdef'; refused "16-hex after a digit and a dot (p1.) refused: no float exemption" E-LEAK "volatile hex run"
terms; mkcmds llllllllll . 'cargo say 0.deadbeefcafebabe'; refused "16-hex after 0. refused: no float exemption" E-LEAK "volatile hex run"
terms; mkcmds llllllllll . 'cargo say r1.0123456789abcdef0123456789abcdef01234567'; refused "40-hex after a digit and a dot refused" E-LEAK "volatile hex run"
terms; mkcmds llllllllll . 'cargo say accuracy: 0.9764705882352941'; accepted "a whole decimal literal (accuracy: 0.9764705882352941) is not a hex run"
terms; mkcmds llllllllll . 'cargo say p1.0123456789012345'; refused "a decimal glued to a letter (p1.) is refused" E-LEAK "volatile hex run"
terms; mkcmds llllllllll . 'cargo say 0123456789abcdef0123'; refused "a bare 20-hex run is refused" E-LEAK "volatile hex run"
terms; mkcmds llllllllll . 'cargo say 1.0123456789012345abc'; refused "a decimal followed by letters is refused" E-LEAK "volatile hex run"
terms; mkcmds llllllllll . 'cargo say v0.1234567890123456.7'; refused "a decimal followed by a dot is refused" E-LEAK "volatile hex run"
terms; mkcmds llllllllll . 'cargo say 0x1.0123456789012345'; refused "a decimal after 0x is refused" E-LEAK "volatile hex run"
terms; mkcmds llllllllll . 'cargo say 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'; refused "a bare 64-hex token is refused" E-LEAK "volatile hex run"
terms; mkcmds llllllllll . 'cargo say max diff = 1.1368683772161603e-12'; accepted "an exponent decimal literal is not a hex run"
terms; mkcmds llllllllll . 'cargo say -0.9764705882352941, 1.1368683772161603E+12'; accepted "a signed decimal before a comma, and an E exponent, are not hex runs"
terms; mkcmds llllllllll . 'cargo say x=0000000000000000000000'; refused "only exactly 16 or 40 zeros are the tokenised values" E-LEAK "volatile hex run"
terms; mkcmds llllllllll . 'cargo say token 0000000000000000 and commit=0000000000000000000000000000000000000000'; accepted "the tokenised values (16 zeros, 40 zeros) are accepted"
terms; mkcmds llllllllll . 'cargo say see /usr/share/doc and ./rust/x'; accepted "a system path and a root-relative path are not refused"
terms; mkcmds llllllllll . 'cargo say accuracy: 0.97647 diff = 8.5e-13 id 0123456789abcde'; accepted "short floats and a 15-hex run are not refused"
# AL-47..AL-52: decimal literals that once hid a hex run, verbatim: a long digit run inside a longer token is scanned
terms; mkcmds llllllllll . 'cargo say pkg-1.0123456789012345-rc1'; refused "AL-47 a decimal glued by - inside a longer token (pkg-1.0123456789012345-rc1) refused" E-LEAK "volatile hex run"
terms; mkcmds llllllllll . 'cargo say build/out-0123456789012345.0-x86_64'; refused "AL-48 a 16-digit integer part glued by - refused" E-LEAK "volatile hex run"
terms; mkcmds llllllllll . 'cargo say v1+0.0123456789012345'; refused "AL-49 a decimal glued by + refused" E-LEAK "volatile hex run"
terms; mkcmds llllllllll . 'cargo say 0.01234567e89012345'; refused "AL-50 a long exponent does not hide a hex run" E-LEAK "volatile hex run"
terms; mkcmds llllllllll . 'cargo say sha=0.1e0123456789012345'; refused "AL-51 a 16-digit exponent does not hide a hex run" E-LEAK "volatile hex run"
terms; mkcmds llllllllll . 'cargo say rev:0123456789012345.1'; refused "AL-52 a 16-digit integer part does not hide a hex run" E-LEAK "volatile hex run"
# --- stale output
terms; echo stale >"$T/out.json"; PATH="$T/bin:$PATH" ADS_ROOT="$T/root" ADS_TERM_DIR="$T/terms" ADS_WARM=true "$EMIT" "$T/out.json" >/dev/null 2>&1
[ ! -e "$T/out.json" ] && ok "stale output removed" || bad "stale output removed"
grep -qE '^\s*CARGO_TERM_QUIET' "$HERE/../term-demos/env" && bad "term-demos/env must not set CARGO_TERM_QUIET" || ok "env does not set CARGO_TERM_QUIET"
# --- the repository's own rows
ids=$(sed -E 's/#.*//; /^[[:space:]]*$/d' "$HERE/../term-demos/rows.list" | cut -d' ' -f1 | sort); have=$(cd "$HERE/../term-demos" && for f in *.cmds; do echo "${f%.cmds}"; done | sort)
[ -n "$ids" ] && [ "$ids" = "$have" ] && ok "rows.list equals the .cmds files in the tree" || bad "rows.list equals the .cmds files in the tree"
# AL-53: positive control: all 18 committed rows (their .cmds, .cwd, env and pinned rows.list) pass every guard, with stubs
rm -rf "${T:?}/terms"; cp -R "$HERE/../term-demos" "$T/terms"; accepted "AL-53 all committed rows accepted (form, first words, pins)"
chk "AL-53 18 rows emitted, ids those of rows.list, in byte order" "(.demos|length)==18 and ([.demos[].id]|map(ltrimstr(\"term-\")))==$(printf '%s\n' "$ids" | jq -R . | jq -sc .)"
# AL-54..AL-55: the closed first-word list is held once in the emitter and equals the first words of the committed rows
fwl=$(grep -cE '^FIRST_WORDS=' "$EMIT"); fw=$(sed -nE "s/^FIRST_WORDS='([^']*)'.*/\1/p" "$EMIT" | tr ' ' '\n' | sed '/^$/d' | sort)
used=$(cat "$HERE/../term-demos/"*.cmds | cut -d' ' -f1 | sort -u)
[ "$fwl" -eq 1 ] && [ -n "$fw" ] && [ "$fw" = "$used" ] && [ "$(printf '%s\n' "$fw" | uniq -d)" = "" ] && ok "AL-54 the first-word list equals the committed rows' first words ($(echo $fw))" || bad "AL-54 first-word list [$(echo $fw)] != committed first words [$(echo $used)] (definitions: $fwl)"
hit=; for w in eval sh bash env xargs sudo exec command builtin source; do printf '%s\n' "$fw" | grep -qx "$w" && hit="$hit $w"; done
[ -n "$fw" ] && [ -z "$hit" ] && ok "AL-55 no shell, eval, env, xargs or sudo in the first-word list" || bad "AL-55 forbidden first words in the list:$hit"
# --- every error id the emitter can emit has a refusal arm that was passed above
for id in $(grep -oE 'E-[A-Z]+' "$EMIT" | sort -u); do
  grep -qx "$id" "$T/covered" && ok "error id $id has a passing refusal arm" || bad "error id $id has no passing refusal arm"
done
[ "$fail" -eq 0 ] && echo "falsify-emit-demo-json OK ($arms arms)" || { echo "falsify-emit-demo-json RED ($arms arms)" >&2; exit 1; }
