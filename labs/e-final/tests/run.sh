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
T="no instance/axiom/macro/syntax/elab/set_option/local/open-in/attribute hijack keywords (second layer)"
t bash -c '! grep -nE "^\s*(import|#exit|open\b.*\bin\b|local|scoped|private|protected|unsafe|partial|noncomputable)\b|\b(instance|axiom|macro|macro_rules|#exit|run_cmd|run_elab|run_meta|priority|syntax|elab|elab_rules|set_option|notation|infix|infixl|infixr|prefix|postfix|attribute|opaque|implemented_by|extern|export|csimp|deriving instance)\b|@\[[^]]*(instance|reducible|simp|implemented_by|extern|export|csimp|macro|inline)" "$0"' "$f"
# Root layer. The grader file is [grader prelude] + [learner file] + [grader pins]. The reference sumL and the reference
# statement are elaborated in the PRELUDE, before any learner code, so a learner `instance : Add Int` cannot change them.
# Pins: learner sumL is defeq to the reference fold; the learner's sum_shift TYPE equals the reference statement as an Expr
# (after renaming AgenticDS.sumL -> GraderRef.sumL) and typechecks against it; axioms are checked on the grader theorem;
# the grader's own #eval compares the learner's sumL to the reference at run time and prints the only accepted contract line.
g=$(mktemp -d); trap 'rm -rf "${g:?}"' EXIT
cat > "$g/Mean.lean" <<'PRE'
import Lean
namespace GraderRef
def sumL (xs : List Int) : Int := xs.foldl (· + ·) 0
def stmt : Prop := ∀ (c : Int) (xs : List Int), sumL (xs.map (· + c)) = sumL xs + xs.length * c
end GraderRef
PRE
cat "$f" >> "$g/Mean.lean"
cat >> "$g/Mean.lean" <<'PIN'

example : AgenticDS.sumL = GraderRef.sumL := rfl
theorem grader_sum_shift : GraderRef.stmt := AgenticDS.sum_shift
#print axioms grader_sum_shift
open Lean Elab Command in
#eval show CommandElabM Unit from do
  let env ← getEnv
  let some ci := env.find? ``AgenticDS.sum_shift | throwError "grader: AgenticDS.sum_shift is absent"
  let some rf := env.find? ``GraderRef.stmt | throwError "grader: reference statement is absent"
  let ty := ci.type.replace fun e => if e.isConstOf ``AgenticDS.sumL then some (mkConst ``GraderRef.sumL) else none
  unless ty == rf.value! do throwError "grader: sum_shift type differs from the reference statement"
  logInfo "grader expr: sum_shift type OK"
#eval show IO Unit from do
  for (xs, c) in [([1, 2, 3, 4], 10), ([], 5), ([-7, 3], -2), ([100], 0)] do
    let xs : List Int := xs
    let c : Int := c
    unless AgenticDS.sumL xs == GraderRef.sumL xs && AgenticDS.sumL (xs.map (· + c)) == GraderRef.sumL xs + xs.length * c do
      throw (IO.userError "grader: contract mean_shift violated at run time")
  IO.println "grader contract: mean_shift OK"
PIN

out=$(lean "+$tc" -DwarningAsError=true "$g/Mean.lean" 2>&1); e=$?
T="elaborates, warnings as errors, contract OK"; t bash -c '[ "$1" = 0 ] && echo "$2" | grep -q "^grader contract: mean_shift OK" && echo "$2" | grep -q "grader expr: sum_shift type OK"' x "$e" "$out"
T="axioms of sum_shift within allowed set"; t bash -c '! { echo "$0" | grep "depends on axioms" | grep -vE "\[(propext|Classical.choice|Quot.sound)(, (propext|Classical.choice|Quot.sound))*\]$"; } && echo "$0" | grep -q grader_sum_shift' "$out"
echo "tests run: $n"; [ "$n" -ge 1 ] || exit 2; exit $rc
