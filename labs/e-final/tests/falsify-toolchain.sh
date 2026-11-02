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
# Planted cheats: the grader must exit 1 AND the output must carry the SPECIFIC failure reason (not just rc != 0).
# The first six elaborate fine on their own (so the arm is not vacuous); the io-* ones must never be elaborated outside the grader.
tc=$(tr -d "[:space:]" < "$repo/labs/e-final/lean-toolchain")
arms=0
cheat() { # name reason-substring [standalone]
  if [ "${3:-}" = standalone ]; then
    lean "+$tc" -DwarningAsError=true "$repo/labs/e-final/tests/cheats/$1/Mean.lean" >/dev/null 2>&1 || { echo "FAIL cheat $1 does not elaborate on its own (fixture rotted)"; fail=1; }
  fi
  GRADER_DEBUG=1 bash "$repo/labs/e-final/tests/run.sh" "$repo/labs/e-final/tests/cheats/$1" >"$S/$1.out" 2>&1; rc=$?
  if [ "$rc" -eq 1 ] && grep -q -- "$2" "$S/$1.out"; then echo "arm cheat-$1 ok (rc=1, reason: $2)"; else echo "FAIL arm cheat-$1: rc=$rc, reason '$2' not in output"; fail=1; fi
  arms=$((arms+1))
}
cheat true-statement "sum_shift type differs" standalone
cheat redefined-sumL "Type mismatch" standalone
cheat hijack-add "FAIL test2" standalone
cheat hijack-priority "FAIL test2" standalone
cheat ns-hijack-a "left open" standalone
cheat ns-hijack-b "left open" standalone
cheat io-rewrite-pins "Type mismatch"        # the learner's IO never ran: Pins was not rewritten
cheat io-checkcontract "Type mismatch"       # IO hidden in a redefined checkContract never ran either
cheat unsafecast-skipkernel "FAIL test2"
cheat grader-ref-defs "already contains"
# H: the word "instance" in a comment must NOT trip the keyword layer (comments are stripped first).
mk H; printf "\n-- an instance of the law; set_option and local are only words here\n/- macro syntax elab -/\n" >> "$S/H/labs/e-final/solution/Mean.lean"; chk H 0
# G: root layer alone. Delete both keyword layers from a copy of the grader; the attacks must still be refused by the Lean pins.
mk G; sed -i -e "/hijack keywords/,+1d" -e "/after other text on a line/,+1d" "$S/G/labs/e-final/tests/run.sh"
grep -qE "hijack keywords|after other text" "$S/G/labs/e-final/tests/run.sh" && { echo "FAIL arm G: keyword layers not removed"; fail=1; }
for c in hijack-add io-rewrite-pins io-checkcontract; do
  GRADER_DEBUG=1 bash "$S/G/labs/e-final/tests/run.sh" "$repo/labs/e-final/tests/cheats/$c" >"$S/G-$c.out" 2>&1; rc=$?
  if [ "$rc" -eq 1 ] && grep -q "Type mismatch" "$S/G-$c.out" && ! grep -q "hijack keywords" "$S/G-$c.out"; then echo "arm G-$c root-layer ok (rc=1, Type mismatch)"; else echo "FAIL arm G-$c: rc=$rc want 1 from the Lean pins"; fail=1; fi
done
[ "$fail" -eq 0 ] && echo "falsifier OK (A-C, $arms cheats, H, 3 root-layer arms)"; exit "$fail"
