#!/usr/bin/env bash
# emit-demo-json.sh BIN_DIR OUT.json ID...   (run from lean/AgenticDS; ID = m<M>v<NN>)
# RMV-001 §16 A-3: runs each declared demo once and records what the terminal would show: the command, its exit code,
# its raw stdout, the stdout sha256 and the sha256 of every plot it wrote. Fails closed: a non-zero exit, an empty
# stdout, or (for a demo listed in scripts/contract-demos.txt) a last line that is not `contract: ... OK` stops the run
# and no file is written. The file carries the commit; CI attests it with actions/attest-build-provenance.
set -uo pipefail  # no -e: every jq step below is checked explicitly (ads#194)
BIN=${1:?BIN_DIR}; OUT=${2:?OUT.json}; shift 2
[ "$#" -ge 1 ] || { echo "no demo ids" >&2; exit 2; }
LIST=${CONTRACT_LIST:-scripts/contract-demos.txt}
T=$(mktemp -d); trap 'rm -rf "${T:?}"' EXIT
: >"$T/rows"
for id in "$@"; do
  m=${id#m}; m=${m%%v*}; v=v${id##*v}
  rm -f plot-*.svg
  "$BIN/example-m$m" "$v" >"$T/out" 2>"$T/err"; rc=$?
  [ "$rc" -eq 0 ] || { echo "FAIL $id exit $rc" >&2; exit 1; }
  [ -s "$T/out" ] || { echo "FAIL $id empty stdout (ads#132)" >&2; exit 1; }
  if grep -qx "$id" "$LIST" 2>/dev/null && ! tail -n 1 "$T/out" | grep -Eq '^contract: .* OK$'; then echo "FAIL $id no contract line" >&2; exit 1; fi
  plots=$({ ls plot-*.svg 2>/dev/null || true; } | sort | while read -r p; do printf '%s %s\n' "$(sha256sum <"$p" | cut -d' ' -f1)" "$p"; done | jq -R 'split(" ")|{sha256:.[0],file:.[1]}' | jq -s .) || { echo "FAIL $id plots jq" >&2; exit 1; }
  jq -n --arg id "$id" --arg cmd "lake exe example-m$m $v" --rawfile out "$T/out" --arg sha "$(sha256sum <"$T/out" | cut -d' ' -f1)" --argjson plots "$plots" \
    '{id:$id,command:$cmd,exit:0,stdout:$out,stdout_sha256:$sha,plots:$plots}' >>"$T/rows" || { echo "FAIL $id row jq" >&2; exit 1; }
done
rm -f plot-*.svg
jq -s --arg commit "${GITHUB_SHA:-$(git rev-parse HEAD 2>/dev/null || echo unknown)}" --arg wf "${GITHUB_WORKFLOW:-local}" --arg run "${GITHUB_RUN_ID:-local}" \
  '{schema:"demo-json/v1",course:"ads-c05-lean",commit:$commit,workflow:$wf,run_id:$run,demos:.}' "$T/rows" >"$OUT.tmp" || { rm -f "${OUT:?}.tmp"; echo "FAIL final jq" >&2; exit 1; }
mv "$OUT.tmp" "$OUT"
echo "wrote $OUT ($# demos)"
