import Mathlib
import AgenticDS.Stats
/-! Axioms behind the theorems. -/
open Lean Elab Term

-- The axioms a theorem rests on, read from the kernel when this
-- file elaborates, so running the example imports nothing.
elab "axiomsOf% " n:ident : term => do
  let c ← realizeGlobalConstNoOverloadWithInfo n
  let ax ← collectAxioms c
  return toExpr (ax.toList.map toString)

def m1v07_axioms : List (String × List String) :=
  [("AgenticDS.mean_const", axiomsOf% AgenticDS.mean_const),
   ("AgenticDS.variance_shift", axiomsOf% AgenticDS.variance_shift)]

def m1v07 : IO Unit := do
  for (n, a) in m1v07_axioms do
    IO.println s!"{n} depends on axioms: {a}"
