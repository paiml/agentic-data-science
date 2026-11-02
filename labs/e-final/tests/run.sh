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
# Comments are stripped before the keyword layer reads the file (a word in a comment is not a hijack).
perl -0pe 's{/-.*?-/}{}gs; s{--[^\n]*}{}g' "$f" > "$g/stripped.lean"
T="no instance/axiom/macro/syntax/elab/set_option/local/open-in/attribute hijack keywords (second layer, comments stripped)"
t bash -c '! grep -nE "^\s*(import|#exit|open\b.*\bin\b|local|scoped|private|protected|unsafe|partial|noncomputable)\b|\b(instance|axiom|macro|macro_rules|#exit|run_cmd|run_elab|run_meta|priority|syntax|elab|elab_rules|set_option|notation|infix|infixl|infixr|prefix|postfix|attribute|opaque|implemented_by|extern|export|csimp|deriving instance)\b|@\[[^]]*(instance|reducible|simp|implemented_by|extern|export|csimp|macro|inline)" "$0"' "$g/stripped.lean"
# Root layer: module boundary. Ref.lean (grader-owned reference sumL and statement) and Learner.lean (the learner file)
# each compile to their own .olean; Pins.lean imports both and uses fully _root_-qualified names. No open namespace,
# section, scope, instance or local name of the learner file crosses an import. Learner.lean ends with a grader check that
# no namespace or section is left open. The reference is elaborated in a module the learner never touches.
cat > "$g/Ref.lean" <<'REF'
namespace GraderRef
def sumL (xs : List Int) : Int := xs.foldl (· + ·) 0
def stmt : Prop := ∀ (c : Int) (xs : List Int), sumL (xs.map (· + c)) = sumL xs + xs.length * c
end GraderRef
REF
{ echo "import Lean"; cat "$f"; cat <<'TAIL'

#eval show _root_.Lean.Elab.Command.CommandElabM Unit from do
  unless (← _root_.Lean.Elab.Command.getScopes).length == 1 && (← _root_.Lean.Elab.Command.getScope).currNamespace == _root_.Lean.Name.anonymous do
    _root_.Lean.throwError "grader: a namespace or section is left open at the end of Mean.lean"
TAIL
} > "$g/Learner.lean"
cat > "$g/Pins.lean" <<'PIN'
import Lean
import Ref
import Learner

example : _root_.AgenticDS.sumL = _root_.GraderRef.sumL := rfl
theorem grader_sum_shift : _root_.GraderRef.stmt := _root_.AgenticDS.sum_shift
#print axioms grader_sum_shift
open Lean Elab Command in
#eval show CommandElabM Unit from do
  let env ← getEnv
  let some ci := env.find? ``_root_.AgenticDS.sum_shift | throwError "grader: AgenticDS.sum_shift is absent"
  let some rf := env.find? ``_root_.GraderRef.stmt | throwError "grader: reference statement is absent"
  let ty := ci.type.replace fun e => if e.isConstOf ``_root_.AgenticDS.sumL then some (mkConst ``_root_.GraderRef.sumL) else none
  unless ty == rf.value! do throwError "grader: sum_shift type differs from the reference statement"
  logInfo "grader expr: sum_shift type OK"
#eval show IO Unit from do
  for (xs, c) in [([1, 2, 3, 4], 10), ([], 5), ([-7, 3], -2), ([100], 0)] do
    let xs : List Int := xs
    let c : Int := c
    unless _root_.AgenticDS.sumL xs == _root_.GraderRef.sumL xs && _root_.AgenticDS.sumL (xs.map (· + c)) == _root_.GraderRef.sumL xs + xs.length * c do
      throw (IO.userError "grader: contract mean_shift violated at run time")
  IO.println "grader contract: mean_shift OK"
PIN
out=""; e=0
for m in Ref Learner Pins; do
  if [ "$m" = Pins ]; then o=$(cd "$g" && LEAN_PATH="$g" lean "+$tc" -DwarningAsError=true "$m.lean" 2>&1); else o=$(cd "$g" && LEAN_PATH="$g" lean "+$tc" -DwarningAsError=true -o "$m.olean" "$m.lean" 2>&1); fi
  r=$?; out="$out$o"$'\n'; if [ "$r" -ne 0 ]; then e=$r; break; fi
done
T="elaborates (as modules), warnings as errors, contract OK"; t bash -c '[ "$1" = 0 ] && echo "$2" | grep -q "^grader contract: mean_shift OK" && echo "$2" | grep -q "grader expr: sum_shift type OK"' x "$e" "$out"
T="axioms of sum_shift within allowed set"; t bash -c '! { echo "$0" | grep "depends on axioms" | grep -vE "\[(propext|Classical.choice|Quot.sound)(, (propext|Classical.choice|Quot.sound))*\]$"; } && echo "$0" | grep -q grader_sum_shift' "$out"
echo "tests run: $n"; [ "$n" -ge 1 ] || exit 2; exit $rc
