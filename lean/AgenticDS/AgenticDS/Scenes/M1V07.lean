import AgenticDS.Stats
/-! Axioms behind the theorems. -/
open Lean Elab Term

-- The axioms a theorem rests on, read from the kernel
-- when this file is elaborated: no import at run time.
elab "sceneAxiomsOf% " n:ident : term => do
  let c ← realizeGlobalConstNoOverloadWithInfo n
  let ax ← collectAxioms c
  return toExpr ax.toList

def s1v07_axioms : List (Name × List Name) :=
  [(`AgenticDS.mean_const,
     sceneAxiomsOf% AgenticDS.mean_const),
   (`AgenticDS.variance_shift,
     sceneAxiomsOf% AgenticDS.variance_shift)]

def s1v07 : IO Unit := do
  for (n, a) in s1v07_axioms do
    IO.println s!"{n} depends on axioms: {a}"
