#!/usr/bin/env bash
# Falsifier for scripts/emit-demo-json-r.sh term rows: with a stub Rscript and 40 stub example dirs, the emitter must write
# one term-<hash> row per line of the term map (same stdout and plots as the example it names) and must fail closed on a
# map line naming a missing example, a malformed id, a duplicate id, and an empty map.
set -uo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"; t="$(mktemp -d)"; trap 'rm -rf "${t:?}"' EXIT
mkdir -p "$t/bin" "$t/ex"
cat >"$t/bin/Rscript" <<'S'
#!/usr/bin/env bash
printf 'hello %s\ncontract: stub OK\n' "$(basename "$(dirname "$1")")"
printf '<svg/>' >"$ADS_OUT/plot.svg"
S
chmod +x "$t/bin/Rscript"
for m in 1 2 3 4; do for v in 01 02 03 04 05 06 07 08 09 10; do d="$t/ex/c-m$m-v$v-x"; mkdir -p "$d"; : >"$d/run.R"; done; done
run() { PATH="$t/bin:$PATH" EXAMPLES_DIR="$t/ex" TERM_MAP="$1" bash "$root/scripts/emit-demo-json-r.sh" "$t/out.json" >"$t/log" 2>&1; }
printf 'term-0123456789\tc-m1-v01-x\nterm-abcdef0123\tc-m4-v10-x\n' >"$t/ok.tsv"
run "$t/ok.tsv" || { echo "FAIL: clean map refused"; cat "$t/log"; exit 1; }
n=$(jq '[.demos[]|select(.id|startswith("term-"))]|length' "$t/out.json"); [ "$n" = 2 ] || { echo "FAIL: want 2 term rows, got $n"; exit 1; }
[ "$(jq '.demos|length' "$t/out.json")" = 42 ] || { echo "FAIL: want 40 lesson rows plus 2 term rows"; exit 1; }
a=$(jq -c '.demos[]|select(.id=="term-0123456789")|[.command,.stdout_sha256,.plots]' "$t/out.json")
b=$(jq -c '.demos[]|select(.id=="m1v01")|[.command,.stdout_sha256,.plots]' "$t/out.json")
[ -n "$a" ] && [ "$a" = "$b" ] || { echo "FAIL: term row differs from the example row it names"; exit 1; }
bad() { rm -f "$t/out.json"; if run "$2"; then echo "FAIL: $1 stayed green"; exit 1; fi; [ ! -e "$t/out.json" ] || { echo "FAIL: $1 left a file"; exit 1; }; }
printf 'term-0123456789\tc-m9-v99-x\n' >"$t/missing.tsv"; bad "missing example" "$t/missing.tsv"
printf 'term-0123\tc-m1-v01-x\n' >"$t/short.tsv"; bad "malformed id" "$t/short.tsv"
printf 'term-0123456789\tc-m1-v01-x\nterm-0123456789\tc-m1-v02-x\n' >"$t/dup.tsv"; bad "duplicate id" "$t/dup.tsv"
: >"$t/empty.tsv"; bad "empty map" "$t/empty.tsv"
bad "absent map" "$t/none.tsv"
echo "falsify-emit-demo-json-r OK: clean GREEN, 5 plants RED"
