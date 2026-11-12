#!/usr/bin/env bash
# Falsifier for scripts/emit-demo-json-r.sh term rows: with a stub Rscript and 40 stub example dirs, the emitter must write
# one term-<hash> row per line of the term map (same stdout and plots as the example it names) and must fail closed on a
# map line naming a missing example, a malformed id, a duplicate id, and an empty map. Term rows also carry `commands` (the typed console commands) and `command` (those joined): an extra command must change the row, a changed or missing sourcing command and an empty, non-file or non-sourcing term.cmds must fail closed, a command that prints or a repeated or non-last source() fails closed, CRLF is stripped, and one example's term.cmds never leaks into another row.
set -uo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"; t="$(mktemp -d)"; trap 'rm -rf "${t:?}"' EXIT
mkdir -p "$t/bin" "$t/ex"
cat >"$t/bin/Rscript" <<'S'
#!/usr/bin/env bash
# a typed-commands script (term.R) runs its last source() line; library(stats) adds a line of output, library(nopkg) fails like a missing package
f=$1; extra=
if [ "${f##*/}" = term.R ]; then
  grep -q 'library(nopkg)' "$f" && { echo "there is no package called nopkg" >&2; exit 1; }
  grep -q 'library(stats)' "$f" && extra='masked: stub\n'
  f=$(tail -n 1 "$f" | sed 's/^source("\(.*\)")$/\1/')
fi
printf "hello %s\n${extra}contract: stub OK\n" "$(basename "$(dirname "$f")")"
printf '<svg/>' >"$ADS_OUT/plot.svg"
S
chmod +x "$t/bin/Rscript"
for m in 1 2 3 4; do for v in 01 02 03 04 05 06 07 08 09 10; do d="$t/ex/c-m$m-v$v-x"; mkdir -p "$d"; : >"$d/run.R"; done; done
run() { PATH="$t/bin:$PATH" EXAMPLES_DIR="$t/ex" TERM_MAP="$1" bash "$root/scripts/emit-demo-json-r.sh" "$t/out.json" >"$t/log" 2>&1; }
printf 'term-0123456789\tc-m1-v01-x\nterm-abcdef0123\tc-m4-v10-x\n' >"$t/ok.tsv"
run "$t/ok.tsv" || { echo "FAIL: clean map refused"; cat "$t/log"; exit 1; }
n=$(jq '[.demos[]|select(.id|startswith("term-"))]|length' "$t/out.json"); [ "$n" = 2 ] || { echo "FAIL: want 2 term rows, got $n"; exit 1; }
[ "$(jq '.demos|length' "$t/out.json")" = 42 ] || { echo "FAIL: want 40 lesson rows plus 2 term rows"; exit 1; }
a=$(jq -c '.demos[]|select(.id=="term-0123456789")|[.stdout_sha256,.plots]' "$t/out.json")
b=$(jq -c '.demos[]|select(.id=="m1v01")|[.stdout_sha256,.plots]' "$t/out.json")
[ -n "$a" ] && [ "$a" = "$b" ] || { echo "FAIL: term row differs from the example row it names"; exit 1; }
trow() { jq -c --arg id "$2" '.demos[]|select(.id==$id)|[.command,.commands]' "$1"; }
d1="$t/ex/c-m1-v01-x"; src="source(\"$d1/run.R\")"
[ "$(jq -c '.demos[]|select(.id=="term-0123456789")|.commands' "$t/out.json")" = "[$(jq -n --arg s "$src" '$s')]" ] || { echo "FAIL: term row commands is not the single source() line"; exit 1; }
[ "$(jq -r '.demos[]|select(.id=="term-0123456789")|.command' "$t/out.json")" = "$src" ] || { echo "FAIL: term row command is not its commands joined"; exit 1; }
[ "$(jq -c '.demos[]|select(.id=="m1v01")|has("commands")' "$t/out.json")" = false ] || { echo "FAIL: lesson row grew a commands array"; exit 1; }
base=$(trow "$t/out.json" term-0123456789); [ -n "$base" ] || { echo "FAIL: no term row"; exit 1; }
other=$(trow "$t/out.json" term-abcdef0123)
printf 'library(agenticds)\n%s\n' "$src" >"$d1/term.cmds"; run "$t/ok.tsv" || { echo "FAIL: term.cmds refused"; cat "$t/log"; exit 1; }
two=$(trow "$t/out.json" term-0123456789); [ -n "$two" ] || { echo "FAIL: no term row"; exit 1; }
[ "$(jq -c '.[1]' <<<"$two")" = "[\"library(agenticds)\",$(jq -n --arg s "$src" '$s')]" ] || { echo "FAIL: term.cmds not carried in order"; exit 1; }
[ "$(jq -r '.[0]' <<<"$two")" = "$(printf 'library(agenticds)\n%s\n' "$src")" ] || { echo "FAIL: command is not the commands joined"; exit 1; }
[ "$base" != "$two" ] || { echo "FAIL: an extra command did not change the row"; exit 1; }
[ "$other" = "$(trow "$t/out.json" term-abcdef0123)" ] || { echo "FAIL: one example's term.cmds leaked into another row"; exit 1; }
printf 'library(agenticds)\nsource("y/run.R")\n' >"$d1/term.cmds"; rm -f "${t:?}/out.json"
if run "$t/ok.tsv"; then echo "FAIL: a changed command (source of another file) stayed green"; exit 1; fi
[ ! -e "$t/out.json" ] || { echo "FAIL: a changed command left a file"; exit 1; }
printf 'library(agenticds)\r\nlibrary(stats)\r\n%s\r\n' "$src" >"$d1/term.cmds"; run "$t/ok.tsv" || exit 1
three=$(trow "$t/out.json" term-0123456789); [ -n "$three" ] && [ "$three" != "$two" ] || { echo "FAIL: another extra command did not change the row"; exit 1; }
[ "$(jq -c '.[1]|length' <<<"$three")" = 3 ] && [ "$(jq -r '.[1][1]' <<<"$three")" = 'library(stats)' ] || { echo "FAIL: CRLF kept or command lost"; exit 1; }
jq -e --arg s "library(agenticds)
library(stats)
$src
" '.demos[]|select(.id=="term-0123456789")|.command==$s' "$t/out.json" >/dev/null || { echo "FAIL: command is not the commands joined plus a final newline"; exit 1; }
redrow() { rm -f "${t:?}/out.json"; if run "$t/ok.tsv"; then echo "FAIL: $1 stayed green"; exit 1; fi; [ ! -e "$t/out.json" ] || { echo "FAIL: $1 left a file"; exit 1; }; }
printf 'library(agenticds)\n%s\nprint(1)\n' "$src" >"$d1/term.cmds"; redrow "a command that prints after the source()"
printf 'print(1)\n%s\n' "$src" >"$d1/term.cmds"; redrow "a command that prints before the source()"
printf '%s\n%s\n' "$src" "$src" >"$d1/term.cmds"; redrow "two source() lines for one run"
printf '%s\nlibrary(agenticds)\n' "$src" >"$d1/term.cmds"; redrow "a source() that is not last"
printf 'library(nopkg)\n%s\n' "$src" >"$d1/term.cmds"; redrow "a typed library() that fails to load"
{ echo "system(1)"; yes "library(x)" | head -n 70000; printf '%s\n' "$src"; } >"$d1/term.cmds"; redrow "a non-library line ahead of more than a pipe buffer of library() lines"
printf 'library(stats)\n%s\n' "$src" >"$d1/term.cmds"; run "$t/ok.tsv" || exit 1
[ "$(jq -r '.demos[]|select(.id=="term-0123456789")|.stdout' "$t/out.json")" = "$(printf 'hello c-m1-v01-x\nmasked: stub\ncontract: stub OK\n')" ] && [ "$(jq -r '.demos[]|select(.id=="m1v01")|.stdout' "$t/out.json")" = "$(printf 'hello c-m1-v01-x\ncontract: stub OK\n')" ] || { echo "FAIL: the term row stdout is not from running its typed commands"; exit 1; }
printf '%s\n' "$src" >"$d1/term.cmds"; run "$t/ok.tsv" || exit 1
[ "$(trow "$t/out.json" term-0123456789)" = "$base" ] || { echo "FAIL: the single-command term.cmds differs from the default row"; exit 1; }
printf 'library(agenticds)\n' >"$d1/term.cmds"; rm -f "${t:?}/out.json"
if run "$t/ok.tsv"; then echo "FAIL: a term.cmds that does not source the example stayed green"; exit 1; fi
rm -f "${t:?}/out.json"; printf '\n  \n' >"$d1/term.cmds"
if run "$t/ok.tsv"; then echo "FAIL: a term.cmds with no command stayed green"; exit 1; fi
[ ! -e "$t/out.json" ] || { echo "FAIL: empty term.cmds left a file"; exit 1; }
rm -f "${d1:?}/term.cmds"; mkdir "$d1/term.cmds"
if run "$t/ok.tsv"; then echo "FAIL: a term.cmds that is a directory stayed green"; exit 1; fi
rmdir "$d1/term.cmds"; rm -f "${t:?}/out.json"
d4="$t/ex/c-m4-v10-x"; printf 'library(agenticds)\n%s\n' "$src" >"$d1/term.cmds"; mkdir "$d4/term.cmds"
if run "$t/ok.tsv"; then echo "FAIL: a bad term.cmds on the second row stayed green (a prior row's commands leaked)"; exit 1; fi
rmdir "$d4/term.cmds"; rm -f "${d1:?}/term.cmds"; run "$t/ok.tsv" || exit 1
bad() { rm -f "$t/out.json"; if run "$2"; then echo "FAIL: $1 stayed green"; exit 1; fi; [ ! -e "$t/out.json" ] || { echo "FAIL: $1 left a file"; exit 1; }; }
printf 'term-0123456789\tc-m9-v99-x\n' >"$t/missing.tsv"; bad "missing example" "$t/missing.tsv"
printf 'term-0123\tc-m1-v01-x\n' >"$t/short.tsv"; bad "malformed id" "$t/short.tsv"
printf 'term-0123456789\tc-m1-v01-x\nterm-0123456789\tc-m1-v02-x\n' >"$t/dup.tsv"; bad "duplicate id" "$t/dup.tsv"
: >"$t/empty.tsv"; bad "empty map" "$t/empty.tsv"
bad "absent map" "$t/none.tsv"
echo "falsify-emit-demo-json-r OK: clean GREEN, command plants change the row or fail closed, 5 map plants RED"
