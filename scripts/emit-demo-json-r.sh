#!/usr/bin/env bash
# emit-demo-json-r.sh OUT.json   (run from the repo root, with agenticds installed in R_LIBS)
# demo.json for ads-c03-r (R twin of lean/AgenticDS/scripts/emit-demo-json.sh):
# runs every lesson demo r/agenticds/inst/examples/c-m<M>-v<NN>-*/run.R once and records what the terminal
# would show: the command, its exit code, its raw stdout, the stdout sha256 and the sha256 of every plot it
# wrote (ADS_OUT). Fails closed: a non-zero exit, an empty stdout, a last line that is not `contract: ... OK`, no plot.svg,
# or a lesson count other than 40 stops the run and no file is written. Also writes one row per line of r/term-demos.tsv (term-<id> TAB example dir) under that term id: a copy of the named example row plus `commands`, the typed console commands, one string per command (the example's term.cmds, else its source() line), and `command` as those lines joined. CI uploads and attests the file.
set -uo pipefail  # no -e: every step below is checked explicitly
OUT=${1:?OUT.json}
EX=${EXAMPLES_DIR:-r/agenticds/inst/examples}
WANT=${WANT_DEMOS:-40}
MAP=${TERM_MAP:-r/term-demos.tsv}
T=$(mktemp -d) || exit 1; trap 'rm -rf "${T:?}"' EXIT
: >"$T/rows"
# term map: <term-id><TAB><example dir>, one terminal lesson per line; each names a row that is also emitted under its term id
[ -s "$MAP" ] || { echo "FAIL term map $MAP missing or empty" >&2; exit 1; }
grep -Pv "^term-[0-9a-f]{10}\t[a-z0-9-]+\$" "$MAP" >"$T/badmap"; [ ! -s "$T/badmap" ] || { echo "FAIL malformed term map line: $(head -n 1 "$T/badmap")" >&2; exit 1; }
[ "$(cut -f1 "$MAP" | sort -u | wc -l)" -eq "$(wc -l <"$MAP")" ] || { echo "FAIL duplicate term id in $MAP" >&2; exit 1; }
nt=0
n=0
for dir in "$EX"/c-m[1-4]-v[0-9][0-9]-*/; do
  dir=${dir%/}; name=${dir##*/}
  [ -f "$dir/run.R" ] || { echo "FAIL $name no run.R" >&2; exit 1; }
  m=${name#c-m}; m=${m%%-*}; v=${name#c-m?-v}; v=${v%%-*}; id="m${m}v${v}"
  rm -rf "${T:?}/plots"; mkdir -p "$T/plots"
  ADS_OUT="$T/plots" Rscript "$dir/run.R" >"$T/out" 2>"$T/err"; rc=$?
  [ "$rc" -eq 0 ] || { echo "FAIL $id ($name) exit $rc" >&2; tail -n 20 "$T/err" >&2; exit 1; }
  [ -s "$T/out" ] || { echo "FAIL $id ($name) empty stdout" >&2; exit 1; }
  tail -n 1 "$T/out" | grep -Eq '^contract: .* OK$' || { echo "FAIL $id ($name) no contract line" >&2; exit 1; }
  [ -s "$T/plots/plot.svg" ] || { echo "FAIL $id ($name) no plot.svg" >&2; exit 1; }
  plots=$(cd "$T/plots" && { ls 2>/dev/null || true; } | sort | while read -r p; do printf '%s %s\n' "$(sha256sum <"$p" | cut -d' ' -f1)" "$p"; done | jq -R 'split(" ")|{sha256:.[0],file:.[1]}' | jq -s .) || { echo "FAIL $id plots jq" >&2; exit 1; }
  jq -cn --arg id "$id" --arg cmd "Rscript $dir/run.R" --rawfile out "$T/out" --arg sha "$(sha256sum <"$T/out" | cut -d' ' -f1)" --argjson plots "$plots" \
    '{id:$id,command:$cmd,exit:0,stdout:$out,stdout_sha256:$sha,plots:$plots}' >>"$T/rows" || { echo "FAIL $id row jq" >&2; exit 1; }
  while IFS=$'\t' read -r tid tex; do
    [ "$tex" = "$name" ] || continue
    # typed commands of the console session: the example's own term.cmds (one command per line) when it has one, else the single source() line
    if [ -e "$dir/term.cmds" ]; then cp "$dir/term.cmds" "$T/cmds"; else printf 'source("%s/run.R")\n' "$dir" >"$T/cmds"; fi
    grep -q '[^[:space:]]' "$T/cmds" || { echo "FAIL $tid no typed command for $name" >&2; exit 1; }
    cmds=$(jq -R . "$T/cmds" | jq -s 'map(select(test("[^ \t]")))') || { echo "FAIL $tid commands jq" >&2; exit 1; }
    tail -n 1 "$T/rows" | jq -c --arg id "$tid" --argjson cmds "$cmds" '.id=$id | .commands=$cmds | .command=(($cmds|join("\n"))+"\n")' >>"$T/rows" || { echo "FAIL $tid term row jq" >&2; exit 1; }
    nt=$((nt + 1))
  done <"$MAP"
  n=$((n + 1))
done
[ "$n" -eq "$WANT" ] || { echo "FAIL $n lesson demos, want $WANT" >&2; exit 1; }
[ "$nt" -eq "$(wc -l <"$MAP")" ] || { echo "FAIL $nt term rows emitted, the map names $(wc -l <"$MAP")" >&2; exit 1; }
jq -s --arg commit "${GITHUB_SHA:-$(git rev-parse HEAD 2>/dev/null || echo unknown)}" --arg wf "${GITHUB_WORKFLOW:-local}" --arg run "${GITHUB_RUN_ID:-local}" \
  '{schema:"demo-json/v1",course:"ads-c03-r",commit:$commit,workflow:$wf,run_id:$run,demos:.}' "$T/rows" >"$OUT.tmp" || { rm -f "${OUT:?}.tmp"; echo "FAIL final jq" >&2; exit 1; }
mv "$OUT.tmp" "$OUT" || { echo "FAIL mv $OUT" >&2; exit 1; }
echo "wrote $OUT ($n lesson demos, $nt term rows)"
