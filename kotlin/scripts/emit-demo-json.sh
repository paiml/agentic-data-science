#!/usr/bin/env bash
# emit-demo-json.sh OUT.json [ID...]   (run from anywhere; default IDs = every row of kotlin/scripts/demos.tsv)
# Runs each lesson demo of the Kotlin course once, from kotlin/, and records what the terminal shows: the command
# as recorded, its exit code, its raw output, the output sha256 and the sha256 of every plot it wrote.
# Fails closed: a non-zero exit, an empty output, or output that lacks the row's ready line stops the run and no
# file is written. The file carries the commit; CI attests it.
# GRADLE (default: the pinned wrapper distribution from scripts/fetch-gradle.sh) replaces the recorded `gradle`
# and `./gradlew`; `--offline` is dropped so a cold runner can resolve dependencies.
set -uo pipefail  # no -e: every step below is checked explicitly
OUT=${1:?OUT.json}; shift
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TSV="$ROOT/kotlin/scripts/demos.tsv"
GRADLE="${GRADLE:-$("$ROOT/scripts/fetch-gradle.sh")}" || { echo "FAIL no gradle" >&2; exit 2; }
command -v jq >/dev/null || { echo "FAIL jq not on PATH" >&2; exit 2; }
rows=$(grep -v '^#' "$TSV")
[ "$(printf '%s\n' "$rows" | grep -c .)" -eq 40 ] || { echo "FAIL $TSV must hold 40 lesson rows" >&2; exit 2; }
if [ "$#" -eq 0 ]; then set -- $(printf '%s\n' "$rows" | cut -f1); fi
T=$(mktemp -d); trap 'rm -rf "${T:?}"' EXIT
: >"$T/rows"
for id in "$@"; do
  row=$(printf '%s\n' "$rows" | awk -F'\t' -v id="$id" '$1==id')
  [ -n "$row" ] || { echo "FAIL $id not in $TSV" >&2; exit 2; }
  ready=$(printf '%s' "$row" | cut -f2); cmd=$(printf '%s' "$row" | cut -f3)
  run=$(printf '%s' "$cmd" | sed -E "s#^(\./gradlew|gradle) #$GRADLE #; s# --offline##")
  case "$run" in *--console=plain*) ;; "$GRADLE"*) run="$run --console=plain" ;; esac
  touch "$T/mark"
  (cd "$ROOT/kotlin" && eval "$run") >"$T/out" 2>&1; rc=$?
  [ "$rc" -eq 0 ] || { tail -n 30 "$T/out" >&2; echo "FAIL $id exit $rc: $run" >&2; exit 1; }
  [ -s "$T/out" ] || { echo "FAIL $id empty output" >&2; exit 1; }
  grep -qF -- "$ready" "$T/out" || { tail -n 30 "$T/out" >&2; echo "FAIL $id ready line absent: $ready" >&2; exit 1; }
  plots=$(find "$ROOT" -path "$ROOT/.git" -prune -o \( -name 'plot*.svg' -o -name 'plot*.png' \) -newer "$T/mark" -type f -print | sort |
    while read -r p; do printf '%s %s\n' "$(sha256sum <"$p" | cut -d' ' -f1)" "${p#"$ROOT"/}"; done |
    jq -R 'split(" ")|{sha256:.[0],file:.[1]}' | jq -s .) || { echo "FAIL $id plots jq" >&2; exit 1; }
  jq -n --arg id "$id" --arg cmd "$cmd" --arg ready "$ready" --rawfile out "$T/out" \
    --arg sha "$(sha256sum <"$T/out" | cut -d' ' -f1)" --argjson plots "$plots" \
    '{id:$id,command:$cmd,cwd:"kotlin",exit:0,ready:$ready,stdout:$out,stdout_sha256:$sha,plots:$plots}' >>"$T/rows" ||
    { echo "FAIL $id row jq" >&2; exit 1; }
  echo "ok $id" >&2
done
jq -s --arg commit "${GITHUB_SHA:-$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)}" \
  --arg wf "${GITHUB_WORKFLOW:-local}" --arg run "${GITHUB_RUN_ID:-local}" \
  '{schema:"demo-json/v1",course:"ads-c04-kotlin",commit:$commit,workflow:$wf,run_id:$run,demos:.}' "$T/rows" >"$OUT.tmp" ||
  { rm -f "${OUT:?}.tmp"; echo "FAIL final jq" >&2; exit 1; }
mv "$OUT.tmp" "$OUT"
echo "wrote $OUT ($# demos)"
