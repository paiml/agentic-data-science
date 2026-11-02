#!/usr/bin/env bash
# Falsifier for the toolchain pin in run.sh. Each planted arm must make the grader exit 1; the control must exit 0.
#   A control: lab + reference toolchain agree            -> rc 0
#   B reference lean/AgenticDS/lean-toolchain ABSENT      -> rc 1 (a missing file is a failure, not a pass)
#   C reference differs from the lab lean-toolchain       -> rc 1
#   D theorem sum_shift ... : True := trivial             -> rc 1 (statement is pinned by the grader)
#   E sumL redefined (foldr, propositionally equal)       -> rc 1 (sumL is pinned to the exact fold)
#   F instance : Add Int := ⟨fun _ _ => 0⟩ + fake checkContract -> rc 1 (keyword layer)
#   F2 `instance (priority := high) : Add Int` -> rc 1 (pinned in prelude, before the instance)
#   G the same attack with the keyword layer deleted from a copy of the grader -> rc 1 (root layer: prelude-elaborated reference)
export PATH="$HOME/.elan/bin:$PATH"
set -uo pipefail
repo=$(cd "$(dirname "$0")/../../.." && pwd)
S=$(mktemp -d); trap 'rm -rf "${S:?}"' EXIT
mk() { rm -rf "${S:?}/${1:?}"; mkdir -p "$S/$1/labs" "$S/$1/lean/AgenticDS"; cp -R "$repo/labs/e-final" "$S/$1/labs/"; cp "$repo/lean/AgenticDS/lean-toolchain" "$S/$1/lean/AgenticDS/"; }
fail=0
chk() { # name want
  bash "$S/$1/labs/e-final/tests/run.sh" "$S/$1/labs/e-final/solution" >"$S/$1.out" 2>&1; rc=$?
  if [ "$rc" -eq "$2" ]; then echo "arm $1 ok (rc=$rc)"; else echo "FAIL arm $1: rc=$rc want $2: $(tail -n 1 "$S/$1.out")"; fail=1; fi
}
mk A; chk A 0
mk B; rm -f "${S:?}/B/lean/AgenticDS/lean-toolchain"; chk B 1
mk C; echo "leanprover/lean4:v0.0.0" > "$S/C/lean/AgenticDS/lean-toolchain"; chk C 1
# D/E: planted cheats that elaborate fine on their own (so the arm is not vacuous) and must still be refused by the grader.
tc=$(tr -d "[:space:]" < "$repo/labs/e-final/lean-toolchain")
for c in true-statement redefined-sumL hijack-add hijack-priority; do
  lean "+$tc" -DwarningAsError=true "$repo/labs/e-final/tests/cheats/$c/Mean.lean" >/dev/null 2>&1 || { echo "FAIL cheat $c does not elaborate on its own (fixture rotted)"; fail=1; }
  bash "$repo/labs/e-final/tests/run.sh" "$repo/labs/e-final/tests/cheats/$c" >"$S/$c.out" 2>&1; rc=$?
  if [ "$rc" -eq 1 ]; then echo "arm cheat-$c ok (rc=1)"; else echo "FAIL arm cheat-$c: rc=$rc want 1"; fail=1; fi
done
# G: root layer alone. Delete the keyword test from a copy of the grader; the hijack must still be refused by the Lean pins.
mk G; sed -i "/hijack keywords/,+1d" "$S/G/labs/e-final/tests/run.sh"
grep -q "hijack keywords" "$S/G/labs/e-final/tests/run.sh" && { echo "FAIL arm G: keyword layer not removed"; fail=1; }
bash "$S/G/labs/e-final/tests/run.sh" "$repo/labs/e-final/tests/cheats/hijack-add" >"$S/G.out" 2>&1; rc=$?
if [ "$rc" -eq 1 ] && grep -q "FAIL test3" "$S/G.out" && ! grep -q "hijack keywords" "$S/G.out"; then echo "arm G root-layer ok (rc=1)"; else echo "FAIL arm G: rc=$rc want 1 from the Lean pins"; fail=1; fi
[ "$fail" -eq 0 ] && echo "falsifier OK (8 arms)"; exit "$fail"
