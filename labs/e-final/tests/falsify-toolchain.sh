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
cheat() { # name [standalone]: the FULL grader must refuse (rc 1, a FAIL/REFUSED line); the specific root reason is asserted in the G arms
  if [ "${2:-}" = standalone ]; then
    lean "+$tc" -DwarningAsError=true "$repo/labs/e-final/tests/cheats/$1/Mean.lean" >/dev/null 2>&1 || { echo "FAIL cheat $1 does not elaborate on its own (fixture rotted)"; fail=1; }
  fi
  GRADER_DEBUG=1 bash "$repo/labs/e-final/tests/run.sh" "$repo/labs/e-final/tests/cheats/$1" >"$S/$1.out" 2>&1; rc=$?
  if [ "$rc" -eq 1 ] && grep -qE "^FAIL test|^grader: FAIL|REFUSED" "$S/$1.out"; then echo "arm cheat-$1 ok (rc=1, refused)"; else echo "FAIL arm cheat-$1: rc=$rc, no refusal line"; fail=1; fi
  arms=$((arms+1))
}
rm -f /tmp/e76-executed-by_elab
for c in true-statement redefined-sumL hijack-add hijack-priority ns-hijack-a ns-hijack-b command-elab-hijack init-hook unif-hint custom-axiom; do cheat "$c" standalone; done
for c in io-rewrite-pins io-checkcontract unsafecast-skipkernel grader-ref-defs by-elab-exec guard-exec guard-forge-olean eval-in-term reduce-in-term print-in-term \
  guard-indented guard-after-semicolon guard-col0-in-def p1-blank-indented declare-syntax-cat simproc nested-comment-hide desync-char-literal def-deriving guard-msgs deriving-instance; do cheat "$c"; done
[ ! -e /tmp/e76-desync-ran ] || { echo "FAIL: desync probe ran"; fail=1; rm -f /tmp/e76-desync-ran; }
[ ! -e /tmp/e76-executed-by_elab ] && echo "arm by-elab probe file absent ok" || { echo "FAIL: /tmp/e76-executed-by_elab was created (learner code ran at grade time)"; fail=1; rm -f /tmp/e76-executed-by_elab; }
# H: the word "instance" in a comment must NOT trip the keyword layer (comments are stripped first).
mk H; printf "\n-- an instance of the law; set_option and local are only words here\n/- macro syntax elab -/\n" >> "$S/H/labs/e-final/solution/Mean.lean"; chk H 0
# H2: legitimately nested block comments in the learner file still pass (the compiled bytes are the validated bytes).
mk H2; printf "\n/- outer /- inner -/ still a comment -/\n" >> "$S/H2/labs/e-final/solution/Mean.lean"; chk H2 0
# H3: rmedia-cop lane 2b input: in Lean the nested comment swallows the #guard, so it is NOT live code. The compiled bytes are the validated bytes, so it passes.
mk H3; printf "\n/- a /- b -/\n #guard true -- -/\n" >> "$S/H3/labs/e-final/solution/Mean.lean"; chk H3 0
# M: a tiny GRADER_MEM_MB is refused (parse, compile and grade all run under lean -M).
mk M; GRADER_MEM_MB=20 bash "$S/M/labs/e-final/tests/run.sh" "$S/M/labs/e-final/solution" >"$S/M.out" 2>&1; mrc=$?; if [ "$mrc" -eq 1 ] && grep -qiE "memory|REFUSED|FAIL" "$S/M.out"; then echo "arm M ok (rc=1 under GRADER_MEM_MB=20)"; else echo "FAIL arm M: rc=$mrc"; fail=1; fi

# P: the parser classifier alone (every other layer deleted): each refusal names the command kind.
mk P; sed -i -e "/hijack keywords/,+1d" -e "/after other text on a line/,+1d" -e "/no attribute (@\[/,+1d" -e "/top-level commands are an ALLOWLIST/,+1d" -e "\#no unsafe/unsafeBaseIO#,+1d" -e "/token in the RAW file/,+1d" "$S/P/labs/e-final/tests/run.sh"
parm() { # cheat reason
  GRADER_DEBUG=1 bash "$S/P/labs/e-final/tests/run.sh" "$repo/labs/e-final/tests/cheats/$1" >"$S/P-$1.out" 2>&1; rc=$?
  if [ "$rc" -eq 1 ] && grep -q -- "parse: REFUSED.*$2" "$S/P-$1.out"; then echo "arm P-$1 parser-only ok (rc=1, kind: $2)"; else echo "FAIL arm P-$1: rc=$rc, want 'parse: REFUSED.*$2'"; fail=1; fi
  parms=$((parms+1))
}
parms=0
parm guard-indented guardCmd
parm guard-after-semicolon "parse error"
parm guard-col0-in-def "parse error"
parm p1-blank-indented eval
parm declare-syntax-cat syntaxCat
parm simproc Simproc
parm guard-msgs guardMsgsCmd
parm deriving-instance deriving
parm eval-in-term "parse error"
parm nested-comment-hide guardCmd
parm def-deriving "deriving clause"
parm desync-char-literal "banned token"

# G: root layer alone. Delete every keyword layer AND the parser test from a copy; the attacks must still be refused by the sandbox,
# the timeout and Grade.lean's environment check (kernel replay, defeq, axioms), each with its own reason.
mk G; sed -i -e "/Root of the keyword layer/,+4d" -e "/hijack keywords/,+1d" -e "/after other text on a line/,+1d" -e "/no attribute (@\[/,+1d" -e "/top-level commands are an ALLOWLIST/,+1d" -e "\#no unsafe/unsafeBaseIO#,+1d" -e "/token in the RAW file/,+1d" "$S/G/labs/e-final/tests/run.sh"
grep -qE "Root of the keyword layer|every command parses|hijack keywords|after other text|no attribute|ALLOWLIST|no unsafe|RAW file" "$S/G/labs/e-final/tests/run.sh" && { echo "FAIL arm G: a pre-compile layer was not removed"; fail=1; }
rm -f /tmp/e76-executed-by_elab
garm() { # cheat reason [env assignment]
  env ${3:-X=1} GRADER_DEBUG=1 bash "$S/G/labs/e-final/tests/run.sh" "$repo/labs/e-final/tests/cheats/$1" >"$S/G-$1.out" 2>&1; rc=$?
  if [ "$rc" -eq 1 ] && grep -q -- "$2" "$S/G-$1.out" && ! grep -q "keyword layer refused" "$S/G-$1.out"; then echo "arm G-$1 root-layer ok (rc=1, reason: $2)"; else echo "FAIL arm G-$1: rc=$rc, want 1 with '$2' from the root layer"; fail=1; fi
  groot=$((groot+1))
}
groot=0
garm hijack-add "not kernel-defeq"
garm command-elab-hijack "grader_probe is missing"
garm init-hook "not kernel-defeq"
garm unif-hint "not kernel-defeq"
garm by-elab-exec "type differs"
garm true-statement "type differs"
garm redefined-sumL "not kernel-defeq"
garm custom-axiom "forbidden axiom"
# Resource limits, with a refusal arm each: an unbounded compile is killed by timeout; a memory hog is refused by lean -M.
garm timeout-decide "timed out" GRADER_TIMEOUT=10
garm timeout-decide "memory" GRADER_MEM_MB=64
# Root layer, compile-time execution: the #guard really runs (under bwrap), writes into the learner build dir (Lean.olean forged,
# e76-guard-ran), but Grade reads only the sysroot plus a fresh dir with copies of Ref/Learner oleans: the forged Lean.olean is never
# on its path, and nothing is written to the host cwd.
for c in guard-exec guard-forge-olean; do
  GRADER_DEBUG=1 bash "$S/G/labs/e-final/tests/run.sh" "$repo/labs/e-final/tests/cheats/$c" >"$S/G-$c.out" 2>&1; rc=$?
  if grep -q "^lrn dir:.*\(e76-guard-ran\|Lean.olean\)" "$S/G-$c.out" && grep -q "^mods dir: Learner.olean Ref.olean *$" "$S/G-$c.out" && [ "$rc" -eq 0 ] && [ ! -e "$PWD/e76-guard-ran" ] && [ ! -e "$PWD/Lean.olean" ]; then echo "arm G-$c ok (ran under bwrap, forged file never on Grade's path)"; else echo "FAIL arm G-$c: rc=$rc"; fail=1; fi
  groot=$((groot+1))
done
[ ! -e /tmp/e76-executed-by_elab ] && echo "arm G-by-elab probe file absent ok (compiled under bwrap, private /tmp)" || { echo "FAIL: by_elab ran on the host with the keyword layer deleted"; fail=1; rm -f /tmp/e76-executed-by_elab; }
[ "$fail" -eq 0 ] && echo "falsifier OK (A-C, $arms cheats, H, $parms parser-only arms, $groot root-layer arms)"; exit "$fail"
