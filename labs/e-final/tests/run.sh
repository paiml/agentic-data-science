#!/usr/bin/env bash
# Lab grader: usage run.sh <dir-with-Mean.lean>. Exit 0 only if Mean.lean elaborates with
# warnings-as-errors, has no sorry/admit/native_decide, and sum_shift uses only the allowed axioms.
set -uo pipefail
export PATH="$HOME/.elan/bin:$PATH"
here=$(cd "$(dirname "$0")/.." && pwd); tc=$(tr -d "[:space:]" < "$here/lean-toolchain") || exit 2   # the lab pins its toolchain in lean-toolchain (no hard-coded version)
ref="$here/../../lean/AgenticDS/lean-toolchain"; [ -f "$ref" ] || { echo "FAIL: reference lean/AgenticDS/lean-toolchain is absent (a missing file is a failure, not a pass)"; exit 1; }
if [ "$(tr -d "[:space:]" < "$ref")" != "$tc" ]; then echo "FAIL: lab lean-toolchain differs from lean/AgenticDS/lean-toolchain"; exit 1; fi
f="$1/Mean.lean"; n=0
t() { n=$((n+1)); if "$@"; then echo "PASS test$n: $T"; else echo "FAIL test$n: $T"; rc=1; fi; }
rc=0
T="no sorry/admit/native_decide"; t bash -c '! grep -nE "\b(sorry|admit)\b|native_decide" "$0"' "$f"
# Grader-owned pins, appended AFTER the learner file: the statement of sum_shift is fixed (a `: True` theorem cannot
# typecheck against it) and sumL is fixed to the exact fold (a redefined sumL is not defeq to it).
g=$(mktemp -d); trap 'rm -rf "${g:?}"' EXIT; cp "$f" "$g/Mean.lean"
cat >> "$g/Mean.lean" <<'PIN'

namespace AgenticDS
example : sumL = fun xs : List Int => xs.foldl (· + ·) 0 := rfl
theorem grader_sum_shift : ∀ (c : Int) (xs : List Int), sumL (xs.map (· + c)) = sumL xs + xs.length * c := sum_shift
end AgenticDS
#print axioms AgenticDS.grader_sum_shift
PIN
out=$(lean "+$tc" -DwarningAsError=true "$g/Mean.lean" 2>&1); e=$?
T="elaborates, warnings as errors, contract OK"; t bash -c '[ "$1" = 0 ] && echo "$2" | grep -q "contract: mean_shift OK"' x "$e" "$out"
T="axioms of sum_shift within allowed set"; t bash -c '! { echo "$0" | grep "depends on axioms" | grep -vE "\[(propext|Classical.choice|Quot.sound)(, (propext|Classical.choice|Quot.sound))*\]$"; } && echo "$0" | grep -q sum_shift' "$out"
echo "tests run: $n"; [ "$n" -ge 1 ] || exit 2; exit $rc
