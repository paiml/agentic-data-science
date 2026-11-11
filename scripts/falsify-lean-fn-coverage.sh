#!/usr/bin/env bash
# Falsifier for check-lean-fn-coverage.sh (ads#130): the real package passes, and each planted gap is RED.
# The check reads compiled code, so each planted Lean change is compiled for real (into the check's own
# overlay; the real build is never written). Needs the built package: run after `lake build`.
#
# Speed (gate-lean stage "lean fn coverage"): every arm is independent, so
#   - the arms run in parallel, at most FNCOV_JOBS at a time (default: nproc/4, 2..8; FNCOV_JOBS=1 is serial); the control
#     arm runs first and alone; output order is always arm order. Each arm has its OWN compiled-test cache directory;
#   - an arm's result (exit code + output of the real check run) is cached under sha256 of EVERY input of that arm
#     (scripts/result-cache.sh): the package it checks, the real package and its built library, the Lean toolchain and
#     manifest, the datasets, the check, this script and the helper. A hit replays what a real run returned, and the arm's
#     verdict (ok or FAIL) is judged again from it. A result is stored only after its arm is judged ok. Anything else about an entry
#     -> recompute. ADS_GATE_CACHE_OFF=1: no cache.
set -uo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
chk="$here/scripts/check-lean-fn-coverage.sh"
real="$here/lean/AgenticDS"
# shellcheck source=scripts/result-cache.sh
. "$here/scripts/result-cache.sh"
t="$(mktemp -d)"; trap 'rm -rf "${t:?}"' EXIT
command -v lean >/dev/null || export PATH="$HOME/.elan/bin:$PATH"
nproc_="$(nproc 2>/dev/null || echo 4)"; jobs_="${FNCOV_JOBS:-$((nproc_ / 4))}"
case "$jobs_" in ''|*[!0-9]*|0) jobs_=2;; esac
[ -n "${FNCOV_JOBS:-}" ] || { [ "$jobs_" -lt 2 ] && jobs_=2; [ "$jobs_" -gt 8 ] && jobs_=8; }
rc_prune
mkdir -p "$t/res" "$t/cache"; ln -sfn "$here/datasets" "$t/datasets"
nfresh=0; narm=0
# Inputs shared by every arm, hashed once (toolchain, manifest, the real package and its built library, datasets, the scripts).
common="$(rc_lean_inputs "$here" "$real" "$0")"
fresh() { # a new private copy of the package for the next arm
  nfresh=$((nfresh + 1)); w="$t/w$nfresh"; mkdir -p "$w/p/scripts"
  cp -r "$real/AgenticDS" "$real/AgenticDSTest" "$w/p/"
  cp "$real/scripts/refusals.tsv" "$real/scripts/run-list.tsv" "$w/p/scripts/"; cp "$real/lean-toolchain" "$real/lakefile.toml" "$w/p/"
  cp "$here/scripts/lean-plot.sh" "$w/lean-plot.sh"; cp "$here/scripts/falsify-lean-plot.sh" "$w/arms.sh"
  S="$w/p/AgenticDS/Stats.lean"; R="$w/p/scripts/refusals.tsv"; Z="$w/p/AgenticDSTest/Zz.lean"; RF="$w/p/AgenticDSTest/Refusals.lean"
}
# The real check run for one arm, on that arm's private package copy and its OWN compiled-test cache directory
# ($t/cache/<arm id>, never shared with a parallel arm).
real_run() { # <arm id> <package dir>
  LEAN_PKG="$2/p" LEAN_REAL="$real" REFUSALS="$2/p/scripts/refusals.tsv" TEST_CACHE="$t/cache/$1" RUN_LIST="$2/p/scripts/run-list.tsv" LEAN_PLOT="$2/lean-plot.sh" LEAN_PLOT_ARMS="$2/arms.sh" bash "$chk"
}
judge() { # <arm name> <pass|red> <pattern for red> <package dir>: prints the arm's line(s), returns 0 for ok.
  # The key is the sha256 of every input of THIS arm (shared inputs, arm id, expectation, its package tree); rc_judge stores the
  # result only after the verdict, so an unjudged result is never in the cache.
  local key; key="$( { printf '%s\n%s\n%s\n%s\n' "$common" "$1" "$2" "${3:-}"; hash_tree "$4"; } | rc_key)"
  rc_judge "$key" "$1" "$2" "${3:-}" real_run "$1" "$4"
}
arm() { # name expect(pass|red) grep-pattern-for-red: start the arm on the package prepared by fresh/plant (the control runs alone, first)
  [ -z "${FNCOV_ARMS:-}" ] || [ "$1" = 00-control ] || [[ "$1" =~ $FNCOV_ARMS ]] || return 0  # FNCOV_ARMS=<regex>: run only these arms (the cache falsifier uses it)
  narm=$((narm + 1)); local id; id="$(printf '%03d' "$narm")"
  while [ "$narm" -gt 1 ] && [ "$(jobs -rp | wc -l)" -ge "$jobs_" ]; do wait -n 2>/dev/null || true; done
  ( judge "$1" "$2" "${3:-}" "$w" > "$t/res/$id.out" 2>&1; echo $? > "$t/res/$id.rc" ) &
  [ "$narm" -eq 1 ] && wait
  return 0
}
pin() { # <ndef delta> <nsites delta>: move the pin the way a reviewer would after adding code
  local d s; d="$(sed -n 's/^#pin ndef=\([0-9]*\).*/\1/p' "$R")"; s="$(sed -n 's/.*nsites=\([0-9]*\).*/\1/p' "$R" | head -1)"
  sed -i "s/^#pin .*/#pin ndef=$((d + $1)) nsites=$((s + $2))/" "$R"
}
plant_unwired() { printf 'import AgenticDS.Stats\n%s\n' "$1" > "$Z"; }
plant_main() { plant_unwired "$1"; printf 'zz\tok\tAgenticDSTest/Zz.lean\t../..\tx\n' >> "$w/p/scripts/run-list.tsv"; }
fresh; arm 00-control pass
# FUNCTIONS
fresh; printf '\ndef untestedHelper (n : Nat) : Nat := n + 1\n' >> "$S"; pin 1 0
arm 01-new-function-no-test red 'function Stats.untestedHelper has no test'
fresh; rm -f "$w/p/AgenticDSTest/Refusals.lean"
arm 02-delete-a-test-file red 'run list row refusals: file AgenticDSTest/Refusals.lean does not exist'
fresh; printf '\ndef ghostFn (n : Nat) : Nat := n\n' >> "$S"; pin 1 0
plant_main 'def main : IO Unit := IO.println "ghostFn Stats.ghostFn"'
arm 03-string-only-mention-is-no-test red 'function Stats.ghostFn has no test'
fresh; printf '\ndef ghostFn (n : Nat) : Nat := n\n' >> "$S"; pin 1 0
plant_main '-- ghostFn is only named in a comment
/- ghostFn again -/
def main : IO Unit := pure ()'
arm 04-comment-mention-is-no-test red 'function Stats.ghostFn has no test'
fresh; printf '\ndef ghostFn (n : Nat) : Nat := n\ndef shortName (xs : List Nat) : Nat := xs.length\n' >> "$S"; pin 2 0
plant_main 'def main : IO Unit := IO.println (([1] : List Nat).map id |>.length)'
arm 05-short-library-name-is-no-test red 'function Stats.(ghostFn|shortName) has no test'
fresh; printf '\ndef newMean (xs : List Nat) : Nat := xs.length\n' >> "$S"; pin 1 0
plant_main 'def main : IO Unit := IO.println (newMean [1, 2])'
arm 06-called-by-a-test-main-passes pass
fresh; printf '\ndef helperA (n : Nat) : Nat := n\ndef helperB (n : Nat) : Nat := helperA n\n' >> "$S"; pin 2 0
plant_main 'def main : IO Unit := IO.println (helperB 1)'
arm 07-callee-of-tested-passes pass
fresh; printf '\ndef helperA (n : Nat) : Nat := n\n' >> "$S"; pin 1 0
plant_main 'def helperB (n : Nat) : Nat := helperA n
def main : IO Unit := pure ()'
arm 08-callee-of-a-never-run-test-def red 'function Stats.helperA has no test'
fresh; plant_main 'def neverRun : Nat := 3
def main : IO Unit := pure ()'
arm 09-never-run-test-def red 'test definition AgenticDSTest.Zz.neverRun is never run'
fresh; printf '\ndef m1vzzDemo : IO Unit := pure ()\n' >> "$w/p/AgenticDS/Examples/M1V01.lean"; pin 1 0
arm 10-untested-examples-def red 'function Examples.M1V01.m1vzzDemo has no test'
fresh; printf '\ndef m1vzzBoom : IO Unit := throw (IO.userError "x")\n' >> "$w/p/AgenticDS/Examples/M1V02.lean"; pin 1 1
arm 11-untested-examples-throw red 'refusal path Examples.M1V02.m1vzzBoom \(throw\) has no row'
# REFUSALS
fresh; printf '\ndef refuse (n : Nat) : Option Nat := if n = 0 then none else some n\n' >> "$S"; pin 1 0
plant_main 'def main : IO Unit := IO.println (refuse 1)'
arm 12-new-none-no-row red 'refusal path Stats.refuse \(none\) has no row'
fresh; printf '\ndef boom : IO Unit := throw (IO.userError "x")\n' >> "$S"; pin 1 0
plant_main 'def main : IO Unit := boom'
arm 13-new-throw-no-row red 'refusal path Stats.boom \(throw\) has no row'
fresh; printf '\ndef notRefusal (xs : List Nat) : List Nat := xs.filter (· > 0) ++ []\n' >> "$S"; pin 1 0
plant_main 'def main : IO Unit := IO.println (notRefusal [1])'
arm 14-no-false-site-on-a-list-result pass
fresh; grep -v 'parseRat' "$R" > "$w/r"; cp "$w/r" "$R"
arm 15-row-removed red 'refusal path Csv.parseRat \(none\) has no row'
fresh; sed -i 's/refusal Csv.parseRat none$/refusal Csv.parseRat nowhere/' "$R"
arm 16-label-not-in-test red "is not 'refusal Csv.parseRat none'"
fresh; printf 'Csv\tghost\tnone\trefusals\trefusal Csv.parseRat none\n' >> "$R"
arm 17-stale-row red 'names no refusal site'
fresh; sed -i 's#refusals\trefusal Csv.toRawRow#Gone\trefusal Csv.toRawRow#' "$R"
arm 18-test-file-missing red 'run Gone is not in the run list'
# PIN
fresh; sed -i 's/^#pin ndef=\([0-9]*\)/#pin ndef=1\1/' "$R"
arm 19-pin-ndef-off red 'pin: ndef is pinned at'
fresh; sed -i 's/ nsites=[0-9]*/ nsites=99/' "$R"
arm 20-pin-nsites-off red 'pin: nsites is pinned at 99'
fresh; grep -v '^#pin' "$R" > "$w/r"; cp "$w/r" "$R"
arm 21-pin-removed red "has no '#pin"
# PLOT SCRIPT
fresh; printf '\n[ -n "$1" ] || { echo "FAIL: planted"; exit 2; }\n' >> "$w/lean-plot.sh"
arm 22-plot-new-exit-no-arm red 'refusal exits but refusals.tsv has'
fresh; grep -v '14-clip-no-file' "$w/arms.sh" > "$w/a2"; cp "$w/a2" "$w/arms.sh"
arm 23-plot-arm-deleted red "has no arm '14-clip-no-file'"
# FLOORS
fresh; : > "$R"
arm 24-empty-registry red 'refusal registry .* missing or empty'
fresh; rm -f "${w:?}"/p/AgenticDS/*.lean
arm 25-empty-library red 'found no function'
# ENTRY POINTS COME FROM THE RUN LIST; LABELS TIE TO THE RUN; PRIVATE AND INSTANCE-NAMED DEFS COUNT
fresh; printf '\ndef newMean (xs : List Nat) : Nat := xs.length\n' >> "$S"; pin 1 0
plant_unwired 'def main : IO Unit := IO.println (newMean [1, 2])'
arm 26-unwired-test-file-is-no-entry red 'function Stats.newMean has no test'
fresh; sed -i 's/"refusal Csv.parseRat none:/"refusal Csv.parseRat nxne:/' "$RF"; printf -- '-- ("refusal Csv.parseRat none: a letter after the point")\n' >> "$RF"
arm 27-label-only-in-a-comment red "refusal Csv.parseRat \(none\): no check in AgenticDSTest.Refusals carries the label"
fresh; sed -i 's/"refusal Csv.parseRat none:/"refusal Csv.toRawRow none:/' "$RF"
arm 28-label-borrowed-from-another-site red "refusal Csv.parseRat \(none\): no check in AgenticDSTest.Refusals carries the label"
fresh; printf '\nprivate def hiddenHelper (n : Nat) : Nat := n + 1\n' >> "$S"; pin 1 0
arm 29-untested-private-def red 'function Stats.hiddenHelper has no test'
fresh; printf '\ndef installFoo (n : Nat) : Nat := n\n' >> "$S"; pin 1 0
arm 30-def-named-inst-prefix-is-counted red 'function Stats.installFoo has no test'
fresh; printf '\ndef newMean (xs : List Nat) : Nat := xs.length\n' >> "$S"; pin 1 0
plant_main 'private def hid (n : Nat) : Nat := n
def main : IO Unit := IO.println (newMean [1, 2])'
arm 31-private-test-def-never-run red 'test definition AgenticDSTest.Zz.hid is never run'
wait
pass=0; fail=0
for i in $(seq 1 "$narm"); do
  id="$(printf '%03d' "$i")"
  if [ -f "$t/res/$id.rc" ]; then cat "$t/res/$id.out"; if [ "$(cat "$t/res/$id.rc")" -eq 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); fi
  else echo "  arm $i produced no result FAIL"; fail=$((fail+1)); fi
done
echo "falsify-lean-fn-coverage: $pass passed, $fail failed"; [ "$fail" -eq 0 ]
