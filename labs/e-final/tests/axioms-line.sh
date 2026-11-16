#!/usr/bin/env bash
# Reads the grader output on stdin. Exit 0 only if it carries a "depends on axioms: [...]" line and every axiom listed is
# one of propext, Classical.choice, Quot.sound. The empty set [] (a proof that uses no axiom at all) is accepted.
set -uo pipefail
out=$(cat)
line=$(printf '%s\n' "$out" | grep "depends on axioms") || exit 1
[ "$(printf '%s\n' "$line" | wc -l)" -eq 1 ] || exit 1
printf '%s\n' "$line" | grep -qE "\[((propext|Classical\.choice|Quot\.sound)(, (propext|Classical\.choice|Quot\.sound))*)?\]$"
