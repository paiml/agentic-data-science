import AgenticDS.Stats
import AgenticDS.Examples.M1Data
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
  -- Real data: the kernel's axiom list for each theorem, read at
  -- elaboration. Plotted: theorem number against axioms used.
  let all := m1v07_axioms ++ [("AgenticDS.variance_nonneg",
    axiomsOf% AgenticDS.variance_nonneg)]
  for (n, a) in all.drop 2 do
    IO.println s!"{n} depends on axioms: {a}"
  let pts7 := all.zipIdx.map fun ((_, a), i) =>
    ((i + 1).toFloat, a.length.toFloat)
  AgenticDS.writeScatter "plot-m1v07.svg"
    "Axioms under each theorem"
    "theorem (1 mean_const, 2 variance_shift, 3 variance_nonneg)"
    "axioms used"
    pts7 [] [] [] pts7
