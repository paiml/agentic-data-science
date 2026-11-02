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
cheat redefined-sumL "not kernel-defeq" standalone
cheat hijack-add "FAIL test2" standalone
cheat hijack-priority "FAIL test2" standalone
cheat ns-hijack-a "left open" standalone
cheat ns-hijack-b "left open" standalone
cheat io-rewrite-pins "FAIL test3"     # IO on a line is refused before any compile
cheat io-checkcontract "FAIL test3"
cheat unsafecast-skipkernel "FAIL test2"
cheat grader-ref-defs "already contains"
cheat command-elab-hijack "FAIL test2" standalone   # attack4: @[command_elab] printAxioms/eval/in/declaration (import is refused)
cheat init-hook "FAIL test4" standalone
cheat unif-hint "FAIL test4" standalone
# by_elab: refused before compile AND the probe file is never created (compiling Lean is executing it)
rm -f /tmp/e76-executed-by_elab
cheat by-elab-exec "FAIL test2"
[ ! -e /tmp/e76-executed-by_elab ] && echo "arm by-elab probe file absent ok" || { echo "FAIL: /tmp/e76-executed-by_elab was created (learner code ran at grade time)"; fail=1; rm -f /tmp/e76-executed-by_elab; }
# H: the word "instance" in a comment must NOT trip the keyword layer (comments are stripped first).
mk H; printf "\n-- an instance of the law; set_option and local are only words here\n/- macro syntax elab -/\n" >> "$S/H/labs/e-final/solution/Mean.lean"; chk H 0

# G: root layer alone. Delete all three keyword layers from a copy of the grader; the attacks must still be refused by Grade.lean's
# environment check (kernel replay/defeq/axioms), each with its own reason, and the by_elab probe must not appear on the host.
mk G; sed -i -e "/hijack keywords/,+1d" -e "/after other text on a line/,+1d" -e "/no attribute (@\[/,+1d" "$S/G/labs/e-final/tests/run.sh"
grep -qE "hijack keywords|after other text|no attribute" "$S/G/labs/e-final/tests/run.sh" && { echo "FAIL arm G: keyword layers not removed"; fail=1; }
rm -f /tmp/e76-executed-by_elab
garm() { # cheat reason
  GRADER_DEBUG=1 bash "$S/G/labs/e-final/tests/run.sh" "$repo/labs/e-final/tests/cheats/$1" >"$S/G-$1.out" 2>&1; rc=$?
  if [ "$rc" -eq 1 ] && grep -q -- "$2" "$S/G-$1.out" && ! grep -q "keyword layer refused" "$S/G-$1.out"; then echo "arm G-$1 root-layer ok (rc=1, reason: $2)"; else echo "FAIL arm G-$1: rc=$rc, want 1 with '$2' from the root layer"; fail=1; fi
  groot=$((groot+1))
}
groot=0
garm hijack-add "not kernel-defeq"
garm command-elab-hijack "grader_probe is missing"   # @[command_elab declaration] swallows the grader probe: refused, not passed
garm init-hook "not kernel-defeq"
garm unif-hint "not kernel-defeq"
garm by-elab-exec "type differs"
garm true-statement "type differs"
[ ! -e /tmp/e76-executed-by_elab ] && echo "arm G-by-elab probe file absent ok (compiled under bwrap, private /tmp)" || { echo "FAIL: by_elab ran on the host with the keyword layer deleted"; fail=1; rm -f /tmp/e76-executed-by_elab; }
[ "$fail" -eq 0 ] && echo "falsifier OK (A-C, $arms cheats, H, $groot root-layer arms)"; exit "$fail"
