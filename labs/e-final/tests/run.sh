#!/usr/bin/env bash
# Lab grader: usage run.sh <dir-with-Mean.lean>. Exit 0 only if Mean.lean elaborates with
# warnings-as-errors, has no sorry/admit/native_decide, and sum_shift uses only the allowed axioms.
set -uo pipefail
export PATH="$HOME/.elan/bin:$PATH"
f="$1/Mean.lean"; n=0
t() { n=$((n+1)); if "$@"; then echo "PASS test$n: $T"; else echo "FAIL test$n: $T"; rc=1; fi; }
rc=0
T="no sorry/admit/native_decide"; t bash -c '! grep -nE "\b(sorry|admit)\b|native_decide" "$0"' "$f"
out=$(lean +v4.35.0 -DwarningAsError=true "$f" 2>&1); e=$?
T="elaborates, warnings as errors, contract OK"; t bash -c '[ "$1" = 0 ] && echo "$2" | grep -q "contract: mean_shift OK"' x "$e" "$out"
T="axioms of sum_shift within allowed set"; t bash -c '! { echo "$0" | grep "depends on axioms" | grep -vE "\[(propext|Classical.choice|Quot.sound)(, (propext|Classical.choice|Quot.sound))*\]$"; } && echo "$0" | grep -q sum_shift' "$out"
echo "tests run: $n"; [ "$n" -ge 1 ] || exit 2; exit $rc
