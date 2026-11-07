#!/usr/bin/env bash
# Falsifier for lean-axiom-scan.sh: planted axiom declarations must be refused; clean text and comments must pass.
# Run from lean/AgenticDS.
set -uo pipefail
S=$(mktemp -d); trap 'rm -rf "${S:?}"' EXIT
fail=0
arm() { # name want(0|1) content
  printf '%s\n' "$3" > "$S/T.lean"
  scripts/lean-axiom-scan.sh "$S" >"$S/o" 2>&1; rc=$?
  if [ "$rc" = "$2" ]; then echo "arm $1 ok"; else echo "FAIL arm $1: rc=$rc $(cat "$S/o")"; fail=1; fi
}
arm A-plain-axiom 1 'axiom evil : False'
arm B-private-noncomputable 1 'private noncomputable axiom evil : 1 = 2'
arm C-attribute 1 '@[simp] axiom evil : False'
arm D-indented-in-namespace 1 '  axiom evil : False'
arm E-clean 0 'theorem ok : 1 = 1 := rfl'
arm F-comment-and-ident 0 '-- no axiom here
def axiomCount := 3'
[ "$fail" -eq 0 ] && echo "falsifier OK (6 arms)"
exit "$fail"
