#!/usr/bin/env bash
# Falsifier for check-lean-fn-coverage.sh (ads#130): the real package passes, and each planted gap is RED.
# Text only: no Lean build is needed, the check reads the sources.
set -uo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
chk="$here/scripts/check-lean-fn-coverage.sh"
real="$here/lean/AgenticDS"
t="$(mktemp -d)"; trap 'rm -rf "${t:?}"' EXIT
pass=0; fail=0
fresh() {
  rm -rf "${t:?}/p"; mkdir -p "${t:?}/p/scripts"
  cp -r "$real/AgenticDS" "$real/AgenticDSTest" "${t:?}/p/"
  cp "$real/scripts/refusals.tsv" "${t:?}/p/scripts/"
  cp "$here/scripts/lean-plot.sh" "${t:?}/lean-plot.sh"; cp "$here/scripts/falsify-lean-plot.sh" "${t:?}/arms.sh"
}
run() { LEAN_PKG="$t/p" REFUSALS="$t/p/scripts/refusals.tsv" LEAN_PLOT="$t/lean-plot.sh" LEAN_PLOT_ARMS="$t/arms.sh" bash "$chk" 2>&1; }
arm() { # name expect(pass|red) grep-pattern-for-red
  n="$1"; want="$2"; pat="${3:-}"; out="$(run)"; rc=$?
  if [ "$want" = pass ]; then
    if [ "$rc" -eq 0 ]; then echo "  $n ok"; pass=$((pass+1)); else echo "  $n FAIL (rc=$rc): $out" | tail -3; fail=$((fail+1)); fi
  else
    if [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -qE -- "$pat"; then echo "  $n ok"; pass=$((pass+1)); else echo "  $n FAIL (rc=$rc, wanted RED matching '$pat'): $out" | tail -3; fail=$((fail+1)); fi
  fi
}
S="$t/p/AgenticDS/Stats.lean"; T="$t/p/AgenticDSTest/Refusals.lean"; R="$t/p/scripts/refusals.tsv"
fresh; arm 00-control pass
fresh; printf '\ndef untestedHelper (n : Nat) : Nat := n + 1\n' >> "$S"
arm 01-new-function-no-test red 'function Stats.untestedHelper has no test'
fresh; rm -f "${T:?}"
arm 02-delete-a-test-file red 'function (Plot\.qf|Cv\.readCsv) has no test'
fresh; printf '\ndef ghostFn (n : Nat) : Nat := n\n' >> "$S"; printf '\n-- ghostFn is only named in a comment\n/- ghostFn again -/\n' >> "$T"
arm 03-comment-mention-is-no-test red 'function Stats.ghostFn has no test'
fresh; printf '\ndef newMean (xs : List Nat) : Nat := xs.length\n' >> "$S"; printf '\ndef zzTouch := newMean []\n' >> "$T"
arm 04-named-by-a-test-passes pass
fresh; printf '\ndef helperA (n : Nat) : Nat := n\ndef helperB (n : Nat) : Nat := helperA n\n' >> "$S"; printf '\ndef zzUse := helperB 1\n' >> "$T"
arm 05-callee-of-tested-passes pass
fresh; printf '\ndef refuse (n : Nat) : Option Nat := if n = 0 then none else some n\n' >> "$S"; printf '\ndef zzR := refuse 1\n' >> "$T"
arm 06-new-none-no-row red 'refusal path Stats.refuse \(none\) has no row'
fresh; printf '\ndef boom : IO Unit := throw (IO.userError "x")\n' >> "$S"; printf '\ndef zzB := boom\n' >> "$T"
arm 07-new-throw-no-row red 'refusal path Stats.boom \(throw\) has no row'
fresh; grep -v 'parseRat' "$R" > "$t/r"; cp "$t/r" "$R"
arm 08-row-removed red 'refusal path Csv.parseRat \(none\) has no row'
fresh; sed -i 's/refusal Csv.parseRat none$/refusal Csv.parseRat nowhere/' "$R"
arm 09-label-not-in-test red "does not carry the label 'refusal Csv.parseRat nowhere'"
fresh; printf 'Csv\tghost\tnone\tAgenticDSTest/Refusals.lean\trefusal Csv.parseRat none\n' >> "$R"
arm 10-stale-row red 'names no refusal site'
fresh; sed -i 's#AgenticDSTest/Refusals.lean\trefusal Csv.toRawRow#AgenticDSTest/Gone.lean\trefusal Csv.toRawRow#' "$R"
arm 11-test-file-missing red 'test file AgenticDSTest/Gone.lean does not exist'
fresh; printf '\n[ -n "$1" ] || { echo "FAIL: planted"; exit 2; }\n' >> "$t/lean-plot.sh"
arm 12-plot-new-exit-no-arm red 'refusal exits but refusals.tsv has'
fresh; grep -v '14-clip-no-file' "$t/arms.sh" > "$t/a2"; cp "$t/a2" "$t/arms.sh"
arm 13-plot-arm-deleted red "has no arm '14-clip-no-file'"
fresh; : > "$R"
arm 14-empty-registry red 'refusal registry .* missing or empty'
fresh; rm -f "${t:?}"/p/AgenticDS/*.lean
arm 15-empty-library red 'found no function'
echo "falsify-lean-fn-coverage: $pass passed, $fail failed"; [ "$fail" -eq 0 ]
