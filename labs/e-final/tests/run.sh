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
g=$(mktemp -d); trap 'rm -rf "${g:?}"' EXIT
# Comments are stripped (string-aware: a "--" inside a string literal does not start a comment) before the keyword layer reads the file.
perl -0pe 's{("(?:\\.|[^"\\])*")|/-.*?-/|--[^\n]*}{defined $1 ? $1 : ""}gse' "$f" > "$g/stripped.lean"
T="no instance/axiom/macro/syntax/elab/set_option/local/open-in/attribute/unsafeCast/initialize hijack keywords (second layer, comments stripped)"
t bash -c '! grep -nE "^\s*(import|#exit|open\b.*\bin\b|local|scoped|private|protected|unsafe|partial|noncomputable)\b|\b(instance|axiom|macro|macro_rules|#exit|run_cmd|run_elab|run_meta|priority|syntax|elab|elab_rules|set_option|notation|infix|infixl|infixr|prefix|postfix|attribute|opaque|implemented_by|extern|export|csimp|deriving instance|unsafeCast|ofReduceBool|trustCompiler|lcProof|sorryAx|initialize|builtin_initialize|run_tac|debug)\b|@\[[^]]*(instance|reducible|simp|implemented_by|extern|export|csimp|macro|inline)" "$0"' "$g/stripped.lean"
T="no #eval/#print/#check/run_cmd after other text on a line (those commands are only accepted at a line start, where the grader drops them)"
t bash -c '! grep -nE "[^[:space:]].*(#eval|#print|#check|#reduce|#synth|#exit|run_cmd|run_tac)" "$0"' "$g/stripped.lean"
T="no attribute (@[ ... ], attribute), by_elab, unif_hint, command_elab, term_elab, register_option or init hook of any kind"
t bash -c '! grep -nE "@\[|\b(by_elab|unif_hint|command_elab|term_elab|tactic_elab|register_option|register_builtin_option|builtin_init|init)\b" "$0"' "$g/stripped.lean"
# Keyword layer first: if ANY check above tripped, Learner is never compiled (compiling Lean is executing it: elaborators run).
if [ "$rc" -ne 0 ]; then echo "tests run: $n"; echo "grader: keyword layer refused Mean.lean; it was not compiled"; exit 1; fi
# Model (honest): compiling Lean IS execution. Learner.lean compiles from a comment-stripped grader copy (no import, so no meta code
# can be written) in a throwaway dir holding nothing of the grader's, under bwrap (read-only /, no network, private /tmp, only that
# dir writable) where bwrap works. The VERDICT never comes from elaborating commands in an environment holding learner code: Grade.lean
# (grader-owned, written and sha256-checked after the compile) imports Ref and Learner without running initializers and reads the
# environment: kernel replay of the learner's constants, kernel defeq of sumL and of the sum_shift statement to Ref's, axioms.
mkdir -p "$g/ref" "$g/lrn" "$g/grade"
cat > "$g/ref/Ref.lean" <<'REF'
namespace GraderRef
def sumL (xs : List Int) : Int := xs.foldl (· + ·) 0
def stmt : Prop := ∀ (c : Int) (xs : List Int), sumL (xs.map (· + c)) = sumL xs + xs.length * c
end GraderRef
REF
perl -ne 'if (/^\s*(#eval|#print|#check|#reduce|#synth|run_cmd|run_tac)\b/) { $skip=1; next } if ($skip && /^\s+\S/) { next } $skip=0; print' "$g/stripped.lean" > "$g/body.lean"
{ cat "$g/body.lean"; printf '\ntheorem grader_probe : True := trivial\n'; } > "$g/lrn/Learner.lean"
lean_c() { # dir module [-o]
  (cd "$1" && LEAN_PATH="$g/ref:$g/lrn" lean "+$tc" -DwarningAsError=true ${3:+-o "$2.olean"} "$2.lean" 2>&1)
}
lean_sandbox() { # learner compile: bwrap when it works here, plain otherwise
  if bwrap --ro-bind / / --dev /dev --proc /proc true 2>/dev/null; then
    (cd "$g/lrn" && bwrap --ro-bind / / --dev /dev --proc /proc --unshare-net --tmpfs /tmp --ro-bind "$g/ref" "$g/ref" --bind "$g/lrn" "$g/lrn" \
      env LEAN_PATH="$g/ref:$g/lrn" lean "+$tc" -DwarningAsError=true -o Learner.olean Learner.lean 2>&1)
  else lean_c "$g/lrn" Learner -o; fi
}
e=0; out=""
o=$(lean_c "$g/ref" Ref -o); r=$?; [ "$r" -ne 0 ] && { e=$r; out="$o"; }
if [ "$e" -eq 0 ]; then refsha=$(sha256sum "$g/ref/Ref.olean" | cut -d' ' -f1); o=$(lean_sandbox); r=$?; [ "$r" -ne 0 ] && { e=$r; out="$o"; }; fi
if [ "$e" -eq 0 ]; then
cat > "$g/grade/Grade.lean" <<'GRADE'
import Lean
open Lean

def okAxioms : List Name := [`propext, `Classical.choice, `Quot.sound]

def fail (msg : String) : IO UInt32 := do
  IO.println s!"grader: FAIL {msg}"
  return 1

def main : IO UInt32 := do
  initSearchPath (← findSysroot)
  let env ← importModules #[{ module := `Ref }, { module := `Learner }] {} (loadExts := false)
  let some li := env.getModuleIdx? `Learner | return (← fail "Learner module not found")
  let lconsts := env.header.moduleData[li.toNat]!.constants
  unless lconsts.any (·.name == `grader_probe) do
    return (← fail "grader_probe is missing or not a root name (a namespace was left open at the end of Mean.lean, or command elaborators were hijacked)")
  let some ci := env.find? `AgenticDS.sum_shift | return (← fail "AgenticDS.sum_shift is absent")
  let some rs := env.find? `GraderRef.stmt | return (← fail "reference statement is absent")
  let base ← importModules #[{ module := `Ref }] {} (loadExts := false)
  let mut m : Std.HashMap Name ConstantInfo := {}
  for c in lconsts do m := m.insert c.name c
  try
    let _ ← Kernel.Environment.replay m base.toKernelEnv
  catch e => return (← fail s!"kernel replay refused the learner constants: {e}")
  match Kernel.isDefEq env {} (mkConst `AgenticDS.sumL) (mkConst `GraderRef.sumL) with
  | .ok true => pure ()
  | _ => return (← fail "AgenticDS.sumL is not kernel-defeq to the reference fold")
  match Kernel.isDefEq env {} ci.type rs.value! with
  | .ok true => pure ()
  | _ => return (← fail "sum_shift type differs from the reference statement")
  unless ci.isTheorem do return (← fail "sum_shift is not a theorem")
  let (axs, _) ← (Core.CoreM.toIO (collectAxioms `AgenticDS.sum_shift) { fileName := "", fileMap := default } { env })
  IO.println s!"'AgenticDS.sum_shift' depends on axioms: {axs.toList}"
  for a in axs do
    unless okAxioms.contains a do return (← fail s!"sum_shift depends on a forbidden axiom {a}")
  let ref (xs : List Int) : Int := xs.foldl (· + ·) 0
  for (xs, c) in [([1, 2, 3, 4], (10 : Int)), ([], 5), ([-7, 3], -2), ([100], 0)] do
    unless ref (xs.map (· + c)) == ref xs + xs.length * c do return (← fail "contract mean_shift violated")
  IO.println "grader contract: mean_shift OK"
  IO.println "grader expr: sum_shift type OK"
  IO.println "grader verdict: PASS"
  return 0
GRADE
  gsha=$(sha256sum "$g/grade/Grade.lean" | cut -d' ' -f1)
  if [ "$(sha256sum "$g/ref/Ref.olean" | cut -d' ' -f1)" != "$refsha" ]; then e=1; out="grader: Ref.olean was modified while the learner file compiled"
  else
    out=$(cd "$g/grade" && LEAN_PATH="$g/ref:$g/lrn" lean "+$tc" --run Grade.lean 2>&1); e=$?
    [ "$(sha256sum "$g/grade/Grade.lean" | cut -d' ' -f1)" = "$gsha" ] || { e=1; out="grader: Grade.lean was modified while checking"; }
  fi
fi
T="compiles (warnings as errors) and the grader's environment check passes (verdict from Grade.lean only)"; t bash -c '[ "$1" = 0 ] && echo "$2" | grep -q "^grader verdict: PASS" && echo "$2" | grep -q "^grader contract: mean_shift OK"' x "$e" "$out"
T="axioms of sum_shift within allowed set"; t bash -c '! { echo "$0" | grep "depends on axioms" | grep -vE "\[(propext|Classical.choice|Quot.sound)(, (propext|Classical.choice|Quot.sound))*\]$"; } && echo "$0" | grep -q "depends on axioms"' "$out"
[ -n "${GRADER_DEBUG:-}" ] && echo "$out" >&2
echo "tests run: $n"; [ "$n" -ge 1 ] || exit 2; exit $rc
