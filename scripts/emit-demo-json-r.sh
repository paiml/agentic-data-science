#!/usr/bin/env bash
# emit-demo-json-r.sh OUT.json   (run from the repo root, with agenticds installed in R_LIBS)
# demo.json for ads-c03-r (R twin of lean/AgenticDS/scripts/emit-demo-json.sh):
# runs every lesson demo r/agenticds/inst/examples/c-m<M>-v<NN>-*/run.R once and records what the terminal
# would show: the command, its exit code, its raw stdout, the stdout sha256 and the sha256 of every plot it
# wrote (ADS_OUT). Fails closed: a non-zero exit, an empty stdout, a last line that is not `contract: ... OK`, no plot.svg,
# or a lesson count other than 40 stops the run and no file is written. Also writes one row per line of r/term-demos.tsv (term-<id> TAB example dir) under that term id: its own run of the typed `commands`, one string per command (the example's term.cmds, else its source() line), run as one R script whose stdout and plots the row carries, and `command` as those lines joined with a final newline (the Rust row shape); term.cmds may hold only library(<pkg>) lines then one source() of that example, so the typed sequence is exactly what produced the stdout (which comes from Rscript on the same run.R). CI uploads and attests the file.
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
# run_one TAG SCRIPT: runs `Rscript SCRIPT` with ADS_OUT=$T/plots; fails closed; leaves stdout in $T/out and the plot hashes (json) in $plots
run_one() {
  rm -rf "${T:?}/plots"; mkdir -p "$T/plots"
  ADS_OUT="$T/plots" Rscript "$2" >"$T/out" 2>"$T/err" </dev/null; rc=$?
  [ "$rc" -eq 0 ] || { echo "FAIL $1 exit $rc" >&2; tail -n 20 "$T/err" >&2; exit 1; }
  [ -s "$T/out" ] || { echo "FAIL $1 empty stdout" >&2; exit 1; }
  tail -n 1 "$T/out" | grep -Eq '^contract: .* OK$' || { echo "FAIL $1 no contract line" >&2; exit 1; }
  [ -s "$T/plots/plot.svg" ] || { echo "FAIL $1 no plot.svg" >&2; exit 1; }
  plots=$(cd "$T/plots" && { ls 2>/dev/null || true; } | sort | while read -r p; do printf '%s %s\n' "$(sha256sum <"$p" | cut -d' ' -f1)" "$p"; done | jq -R 'split(" ")|{sha256:.[0],file:.[1]}' | jq -s .) || { echo "FAIL $1 plots jq" >&2; exit 1; }
}
n=0
for dir in "$EX"/c-m[1-4]-v[0-9][0-9]-*/; do
  dir=${dir%/}; name=${dir##*/}
  [ -f "$dir/run.R" ] || { echo "FAIL $name no run.R" >&2; exit 1; }
  m=${name#c-m}; m=${m%%-*}; v=${name#c-m?-v}; v=${v%%-*}; id="m${m}v${v}"
  run_one "$id ($name)" "$dir/run.R"
  jq -cn --arg id "$id" --arg cmd "Rscript $dir/run.R" --rawfile out "$T/out" --arg sha "$(sha256sum <"$T/out" | cut -d' ' -f1)" --argjson plots "$plots" \
    '{id:$id,command:$cmd,exit:0,stdout:$out,stdout_sha256:$sha,plots:$plots}' >>"$T/rows" || { echo "FAIL $id row jq" >&2; exit 1; }
  while IFS=$'\t' read -r tid tex; do
    [ "$tex" = "$name" ] || continue
    # typed commands of the console session: the example's own term.cmds (one command per line) when it has one, else the single source() line
    rm -f "${T:?}/cmds"
    if [ -e "$dir/term.cmds" ]; then { [ -f "$dir/term.cmds" ] && tr -d '\r' <"$dir/term.cmds" >"$T/cmds"; } || { echo "FAIL $tid $dir/term.cmds is not a readable regular file" >&2; exit 1; }
    else printf 'source("%s/run.R")\n' "$dir" >"$T/cmds"; fi
    grep '[^[:space:]]' "$T/cmds" >"$T/cmds2" && mv "$T/cmds2" "$T/cmds" || { echo "FAIL $tid no typed command for $name" >&2; exit 1; }
    # exactly one source() of this example, last, after only library(<pkg>) lines
    [ "$(grep -cxF "source(\"$dir/run.R\")" "$T/cmds")" -eq 1 ] && [ "$(tail -n 1 "$T/cmds")" = "source(\"$dir/run.R\")" ] || { echo "FAIL $tid term.cmds of $name must end in exactly one source(\"$dir/run.R\")" >&2; exit 1; }
    sed '$d' "$T/cmds" >"$T/pre" && grep -Evq '^library\([A-Za-z][A-Za-z0-9.]*\)$' "$T/pre" && { echo "FAIL $tid term.cmds of $name: only library(<pkg>) lines may precede the source()" >&2; exit 1; }
    # the row's stdout and plots come from running those typed commands themselves, in one R session
    cp "$T/cmds" "$T/term.R" || { echo "FAIL $tid copy term.R" >&2; exit 1; }
    run_one "$tid ($name typed commands)" "$T/term.R"
    jq -R . "$T/cmds" | jq -s . >"$T/cmds.json" || { echo "FAIL $tid commands jq" >&2; exit 1; }
    jq -cn --arg id "$tid" --slurpfile cmdsf "$T/cmds.json" --rawfile out "$T/out" --arg sha "$(sha256sum <"$T/out" | cut -d' ' -f1)" --argjson plots "$plots" \
      '{id:$id,command:(($cmdsf[0]|join("\n"))+"\n"),commands:$cmdsf[0],exit:0,stdout:$out,stdout_sha256:$sha,plots:$plots}' >>"$T/rows" || { echo "FAIL $tid term row jq" >&2; exit 1; }
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
