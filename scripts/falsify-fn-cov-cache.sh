#!/usr/bin/env bash
# End-to-end falsifier for the result cache of falsify-lean-fn-coverage.sh (real Lean, three arms: control, a red, a second red).
# Proves: cold = warm = uncached = serial output and exit code; a warm run is all hits, a changed arm / script / toolchain / real
# package is all misses and the gate still catches the planted gap; every kind of corrupted entry is recomputed, never replayed.
# Needs the built package (run after `lake build`). The cache, the copy of the repo scripts and all traces live in a temp dir.
set -uo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$HOME/.elan/bin:$PATH"
st0="$(git -C "$here" status --porcelain --ignored 2>/dev/null)"
t="$(mktemp -d)"; trap 'rm -rf "${t:?}"' EXIT; pass=0; fail=0
ok() { echo "  $1 ok"; pass=$((pass+1)); }
bad() { echo "  $1 FAIL: $2"; fail=$((fail+1)); }
# A private copy of the repo layout: scripts are copied (so one can be edited), the Lean package is a copy of its sources with the
# built .lake linked, datasets linked.
repo="$t/repo"; real="$repo/lean/AgenticDS"; src="$here/lean/AgenticDS"
mkdir -p "$real" "$repo/scripts"; cp -r "$here"/scripts/. "$repo/scripts/"; ln -s "$here/datasets" "$repo/datasets"
cp -r "$src/AgenticDS" "$src/AgenticDSTest" "$src/scripts" "$real/"; cp "$src"/lakefile.toml "$src"/lean-toolchain "$src"/lake-manifest.json "$real/"
ln -s "$src/.lake" "$real/.lake"; [ -f "$src/AgenticDS.lean" ] && cp "$src/AgenticDS.lean" "$real/"
S0=falsify-lean-fn-coverage.sh
(cd "$real" && lake build AgenticDS >/dev/null 2>&1)   # the gate builds the library in stage 1; a key is only stable once it is built
export ADS_GATE_CACHE="$t/cache"; ARMS='^(01-|12-)'   # control + 01 + 12: one function gap, one refusal gap
cnt() { grep -c "^$1 " "$t/trace" 2>/dev/null || true; }
run() { # <label> <script> [VAR=val ...]: stdout in $t/<label>.out, exit code in $t/<label>.rc, seconds in $t/<label>.s
  local label="$1" script="$2" s0; shift 2
  : > "$t/trace"; s0=$SECONDS
  env "$@" ADS_GATE_CACHE_TRACE="$t/trace" FNCOV_ARMS="$ARMS" bash "$repo/scripts/$script" > "$t/$label.out" 2>&1; echo $? > "$t/$label.rc"
  echo $((SECONDS - s0)) > "$t/$label.s"
}
same() { cmp -s "$t/$1.out" "$t/$2.out" && [ "$(cat "$t/$1.rc")" = "$(cat "$t/$2.rc")" ]; }
entries() { find "$t/cache" -maxdepth 1 -name '*.entry' | LC_ALL=C sort; }

run cold $S0; entries > "$t/cold.entries"
if [ "$(cat "$t/cold.rc")" = 0 ] && grep -q '3 passed, 0 failed' "$t/cold.out" && [ "$(cnt miss)" = 3 ] && [ "$(cnt hit)" = 0 ] && [ "$(entries | wc -l)" = 3 ]; then ok "00-cold-run-3-misses-3-entries"; else bad 00-cold-run-3-misses-3-entries "rc=$(cat "$t/cold.rc") miss=$(cnt miss) hit=$(cnt hit)"; tail -5 "$t/cold.out"; fi
run warm $S0
if same cold warm && [ "$(cnt hit)" = 3 ] && [ "$(cnt miss)" = 0 ]; then ok "01-warm-run-same-output-3-hits"; else bad 01-warm-run-same-output-3-hits "hits=$(cnt hit) misses=$(cnt miss)"; fi
before="$(entries | xargs sha256sum)"
run off $S0 ADS_GATE_CACHE_OFF=1
if same cold off && [ ! -s "$t/trace" ] && [ "$(entries | xargs sha256sum)" = "$before" ]; then ok "02-uncached-same-output-cache-untouched"; else bad 02-uncached-same-output-cache-untouched "differs"; fi
run serial $S0 ADS_GATE_CACHE_OFF=1 FNCOV_JOBS=1
run par $S0 ADS_GATE_CACHE_OFF=1 FNCOV_JOBS=4
if same serial par && same serial cold; then ok "03-serial-equals-parallel-equals-cached"; else bad 03-serial-equals-parallel-equals-cached "differs"; fi

# An edited planted arm (arm 01 now plants nothing, so its expected RED cannot happen): the script text is part of every key.
sed 's/^fresh; printf .*untestedHelper (n.*$/fresh/' "$repo/scripts/falsify-lean-fn-coverage.sh" > "$repo/scripts/falsify-edited.sh"
cmp -s "$repo/scripts/falsify-edited.sh" "$repo/scripts/falsify-lean-fn-coverage.sh" && bad 04-edit-applied "the sed edit changed nothing"
run edited falsify-edited.sh
if [ "$(cnt hit)" = 0 ] && [ "$(cnt miss)" = 3 ] && [ "$(cat "$t/edited.rc")" != 0 ] && grep -q '01-new-function-no-test FAIL' "$t/edited.out"; then ok "04-edited-arm-all-miss-and-still-caught"; else bad 04-edited-arm-all-miss-and-still-caught "hits=$(cnt hit) rc=$(cat "$t/edited.rc")"; fi

# Corrupted entries: truncated, flipped result, another arm's entry copied over.
mapfile -t e < "$t/cold.entries"
cp "${e[0]}" "$t/e0.save"
head -c $(( $(stat -c %s "${e[0]}") - 15 )) "$t/e0.save" > "${e[0]}"
sed -i -e 's/^rc 1$/rc X/' -e 's/^rc 0$/rc 1/' -e 's/^rc X$/rc 0/' "${e[1]}"
cp "$t/e0.save" "${e[2]}"
run corrupt $S0
if same cold corrupt && [ "$(cnt miss)" = 3 ] && [ "$(cnt hit)" = 0 ]; then ok "05-corrupted-entries-recomputed-never-replayed"; else bad 05-corrupted-entries-recomputed-never-replayed "hits=$(cnt hit) misses=$(cnt miss)"; fi
run healed $S0
if same cold healed && [ "$(cnt hit)" = 3 ]; then ok "06-recomputed-entries-hit-again"; else bad 06-recomputed-entries-hit-again "hits=$(cnt hit)"; fi

# A changed toolchain id: a `lean` that reports another version.
mkdir -p "$t/shim"; reallean="$(command -v lean)"
printf '#!/bin/sh\n[ "$1" = "--version" ] && { echo "Lean (version 0.0.0-planted)"; exit 0; }\nexec "%s" "$@"\n' "$reallean" > "$t/shim/lean"; chmod +x "$t/shim/lean"
run toolchain $S0 PATH="$t/shim:$PATH"
if same cold toolchain && [ "$(cnt miss)" = 3 ] && [ "$(cnt hit)" = 0 ]; then ok "07-toolchain-id-changed-all-miss"; else bad 07-toolchain-id-changed-all-miss "hits=$(cnt hit) misses=$(cnt miss)"; fi

# The real-package check (check-lean-fn-coverage-cached.sh): green is replayed byte for byte; a red is never replayed or stored.
wr() { # <label> [VAR=val ...]
  local label="$1"; shift; : > "$t/trace"
  env "$@" ADS_GATE_CACHE_TRACE="$t/trace" bash "$repo/scripts/check-lean-fn-coverage-cached.sh" > "$t/$label.out" 2>&1; echo $? > "$t/$label.rc"
}
wr plain ADS_GATE_CACHE_OFF=1; wr wcold; wr wwarm
if [ "$(cat "$t/plain.rc")" = 0 ] && same plain wcold && same plain wwarm && [ "$(cnt hit)" = 1 ]; then ok "10-real-check-cold-warm-equal-plain-and-warm-hits"; else bad 10-real-check-cold-warm-equal-plain-and-warm-hits "rc=$(cat "$t/plain.rc") hits=$(cnt hit)"; fi
rcfile="$real/scripts/refusals.tsv"; cp "$rcfile" "$t/refusals.save"; grep -v 'parseRat' "$t/refusals.save" > "$rcfile"
wr wred; ls "$t/cache" > "$t/ls.red"
if [ "$(cat "$t/wred.rc")" != 0 ] && grep -q 'RED: refusal path Csv.parseRat (none) has no row' "$t/wred.out" && [ "$(cnt hit)" = 0 ]; then ok "11-real-package-edited-cached-green-not-replayed-red-caught"; else bad 11-real-package-edited-cached-green-not-replayed-red-caught "rc=$(cat "$t/wred.rc") hits=$(cnt hit)"; fi
wr wred2; if [ "$(cat "$t/wred2.rc")" != 0 ] && [ "$(cnt hit)" = 0 ] && cmp -s "$t/wred.out" "$t/wred2.out"; then ok "12-red-never-stored-so-never-replayed"; else bad 12-red-never-stored-so-never-replayed "hits=$(cnt hit)"; fi
cp "$t/refusals.save" "$rcfile"; wr wback; if same plain wback && [ "$(cnt hit)" = 1 ]; then ok "13-restored-package-hits-green-again"; else bad 13-restored-package-hits-green-again "hits=$(cnt hit)"; fi
# the green entry of the real check, corrupted (flipped to a lie): recomputed
mapfile -t all < <(entries); for f in "${all[@]}"; do cp "$f" "$f.keep"; head -c $(( $(stat -c %s "$f") - 9 )) "$f.keep" > "$f"; done
wr wtrunc; if same plain wtrunc && [ "$(cnt hit)" = 0 ] && [ "$(cnt miss)" = 1 ]; then ok "14-truncated-green-entry-recomputed"; else bad 14-truncated-green-entry-recomputed "hits=$(cnt hit) misses=$(cnt miss)"; fi

# A changed real package (one comment line in a library source): every key moves.
printf -- '-- planted comment\n' >> "$real/AgenticDS/Stats.lean"
run realpkg $S0
if same cold realpkg && [ "$(cnt miss)" = 3 ] && [ "$(cnt hit)" = 0 ]; then ok "08-real-package-changed-all-miss"; else bad 08-real-package-changed-all-miss "hits=$(cnt hit) misses=$(cnt miss)"; fi

# The cache is outside the tree: this run created nothing inside the repo checkout.
if [ "$(git -C "$here" status --porcelain --ignored 2>/dev/null)" = "$st0" ]; then ok "09-checkout-stays-clean"; else bad 09-checkout-stays-clean "the run changed the tree status"; fi
echo "  seconds: cold $(cat "$t/cold.s") warm $(cat "$t/warm.s") uncached $(cat "$t/off.s") serial $(cat "$t/serial.s") parallel $(cat "$t/par.s")"
echo "falsify-fn-cov-cache: $pass pass, $fail fail"; [ "$fail" -eq 0 ]
