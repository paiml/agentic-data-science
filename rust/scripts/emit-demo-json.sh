#!/usr/bin/env bash
# emit-demo-json.sh OUT.json [BATCH...]   (run from anywhere; default BATCH = demos/rust-native/m1.batch ... m4.batch)
# Runs every row of the Rust-course demo batches once and records what the terminal shows: the command as typed, its
# exit code, its stdout, the stdout sha256, the wait string and the example and source file the row belongs to.
#
# ID SCHEME: <batch file stem>-<idx>, so demos/rust-native/m2.batch row `04|...` is `m2-04` (stem = module, idx = the
# row's first field; idx is not always contiguous in file order, the id is not renumbered).
# COMMAND: the row's RUN field, or `cargo run --locked --offline --example <example>` when RUN is empty. It runs with
# `bash -c` from the crate directory (ADS_CRATE_DIR, default rust/ads-rust) with ADS_ROOT set to the repository root.
# WAIT: the row's wait string MUST occur in the recorded stdout; a row whose wait string is absent, or empty, fails the
# run and names the row (and the string). There is no unchecked row.
# RECORDED STDOUT: only stdout (cargo's own progress goes to stderr and is not recorded). For `cargo test` rows the
# stdout is normalized so reruns hash identically: the `; finished in 0.00s` timing suffix is removed and each
# consecutive block of `test <name> ... ok` lines is sorted (the harness prints them in thread-completion order).
# The row then carries `"normalized":true`. All other rows are recorded raw.
# TEST FACTS: a `cargo test` row also carries `tests:{passed,failed,ignored,names_sha256}`, parsed from the `test result:`
# line(s) and the sorted `test <name> ... <status>` lines, so a missing, renamed or duplicated test shows in the record.
# The run is refused when there is no `test result:` line, or when failed or ignored is above zero.
# RUN fields run under `bash -o pipefail -c`. The row separator is `|`, so a RUN field cannot itself contain a pipe.
# Fails closed: a malformed row (not 12 pipe-separated fields), an idx that is not two digits, a duplicate id, a non-zero
# exit, an empty stdout, an empty or missing wait string, or bad test facts stops the run and no file is written (any
# earlier OUT.json is removed first). The file carries the commit; CI attests it with actions/attest-build-provenance.
set -uo pipefail  # no -e: every step below is checked explicitly
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT=${1:?OUT.json}; shift
CRATE=${ADS_CRATE_DIR:-$ROOT/rust/ads-rust}
export ADS_ROOT=${ADS_ROOT:-$ROOT}
rm -f "${OUT:?}" "${OUT:?}.tmp"
command -v jq >/dev/null || { echo "FAIL jq not on PATH" >&2; exit 2; }
if [ "$#" -eq 0 ]; then set -- "$ROOT"/demos/rust-native/m1.batch "$ROOT"/demos/rust-native/m2.batch "$ROOT"/demos/rust-native/m3.batch "$ROOT"/demos/rust-native/m4.batch; fi
for b in "$@"; do [ -f "$b" ] || { echo "FAIL batch file not found: $b" >&2; exit 2; }; done
[ -d "$CRATE" ] || { echo "FAIL crate dir not found: $CRATE" >&2; exit 2; }
T=$(mktemp -d); trap 'rm -rf "${T:?}"' EXIT
: >"$T/rows"
n=0; ids=""
normalize() { # stdin -> stdout: drop the timing suffix, sort each block of consecutive `test ` and lab PASS/FAIL lines (parallel harness order varies)
  sed -E 's/; finished in [0-9.]+s//' | awk '
    function flush(  i, j, t) { for (i = 2; i <= n; i++) { t = b[i]; for (j = i - 1; j >= 1 && b[j] > t; j--) b[j + 1] = b[j]; b[j + 1] = t }
      for (i = 1; i <= n; i++) print b[i]; n = 0 }
    /^(test |starter_(PASS|FAIL) |solution_(PASS|FAIL) )/ { b[++n] = $0; next }
    { flush(); print }
    END { flush() }'
}
test_facts() { # FILE (normalized cargo test stdout) -> a JSON object on stdout; on refusal the reason on stdout, non-zero
  local file=$1 p f i h
  grep -qE '^test result:' "$file" || { echo "no test result line"; return 1; }
  read -r p f i < <(grep -E '^test result:' "$file" | awk '{ for (k = 1; k < NF; k++) { if ($(k+1) ~ /^passed/) p += $k; if ($(k+1) ~ /^failed/) f += $k; if ($(k+1) ~ /^ignored/) i += $k } } END { print p+0, f+0, i+0 }')
  [ "$f" -eq 0 ] || { echo "$f failed"; return 1; }
  [ "$i" -eq 0 ] || { echo "$i ignored (an ignored test is not attested)"; return 1; }
  h=$(grep -E '^test .* \.\.\. ' "$file" | LC_ALL=C sort | sha256sum | cut -d' ' -f1)
  jq -nc --argjson p "$p" --argjson f "$f" --argjson i "$i" --arg h "$h" '{passed:$p,failed:$f,ignored:$i,names_sha256:$h}'
}
for batch in "$@"; do
  stem=$(basename "$batch" .batch)
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|'#'*) continue;; esac
    IFS='|' read -r -a f <<<"$line"
    # a trailing empty field is dropped by read; count separators instead
    seps=${line//[^|]/}
    [ "${#seps}" -eq 11 ] || { echo "FAIL $batch: row has $((${#seps} + 1)) fields, want 12: ${line:0:60}" >&2; exit 2; }
    idx=${f[0]}; example=${f[2]}; source=${f[3]}; run=${f[6]:-}; wait=${f[7]:-}
    [[ "$idx" =~ ^[0-9]{2}$ ]] || { echo "FAIL $batch: idx '$idx' is not two digits: ${line:0:60}" >&2; exit 2; }
    id="$stem-$idx"
    case " $ids " in *" $id "*) echo "FAIL duplicate id $id in $batch" >&2; exit 2;; esac
    ids="$ids $id"
    [ -n "$wait" ] || { echo "FAIL $id empty WAIT field (every row must name a string its output shows): ${line:0:60}" >&2; exit 2; }
    cmd=${run:-cargo run --locked --offline --example $example}
    (cd "$CRATE" && bash -o pipefail -c "$cmd") >"$T/out" 2>"$T/err"; rc=$?
    [ "$rc" -eq 0 ] || { echo "FAIL $id exit $rc: $cmd" >&2; tail -n 5 "$T/err" >&2; exit 1; }
    norm=false; tests=null
    case "$cmd" in *cargo\ test*)
      norm=true; normalize <"$T/out" >"$T/out.n" && mv "$T/out.n" "$T/out" || { echo "FAIL $id normalize" >&2; exit 1; }
      tests=$(test_facts "$T/out") || { echo "FAIL $id test facts: $tests" >&2; exit 1; };; esac
    case "$cmd" in *make\ gate-rust*)
      norm=true; normalize <"$T/out" >"$T/out.n" && mv "$T/out.n" "$T/out" || { echo "FAIL $id normalize" >&2; exit 1; };; esac
    [ -s "$T/out" ] || { echo "FAIL $id empty stdout: $cmd" >&2; exit 1; }
    if [ -n "$wait" ] && ! grep -qF -- "$wait" "$T/out"; then
      echo "FAIL $id wait string not in stdout: '$wait' (last line: $(tail -n 1 "$T/out"))" >&2; exit 1
    fi
    jq -n --arg id "$id" --arg cmd "$cmd" --rawfile out "$T/out" --arg sha "$(sha256sum <"$T/out" | cut -d' ' -f1)" \
      --arg wait "$wait" --arg ex "$example" --arg src "$source" --argjson norm "$norm" --argjson tests "$tests" \
      '{id:$id,command:$cmd,exit:0,stdout:$out,stdout_sha256:$sha,plots:[],wait:$wait,example:$ex,source:$src,normalized:$norm,tests:$tests}' >>"$T/rows" || { echo "FAIL $id row jq" >&2; exit 1; }
    n=$((n + 1))
  done <"$batch"
done
[ "$n" -ge 1 ] || { echo "FAIL no demo rows in batches" >&2; exit 2; }
jq -s --arg commit "${GITHUB_SHA:-$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)}" --arg wf "${GITHUB_WORKFLOW:-local}" --arg run "${GITHUB_RUN_ID:-local}" \
  '{schema:"demo-json/v1",course:"ads-c01-rust",commit:$commit,workflow:$wf,run_id:$run,demos:.}' "$T/rows" >"$OUT.tmp" || { rm -f "${OUT:?}.tmp"; echo "FAIL final jq" >&2; exit 1; }
mv "$OUT.tmp" "$OUT"
echo "wrote $OUT ($n demos)"
