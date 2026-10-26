import Mathlib
/-! Axioms behind the theorems. -/
open Lean

-- What a theorem rests on: its axioms, from the kernel.
def m1v07_axioms (n : Name) : IO (List Name) := do
  initSearchPath (← findSysroot)
  let i : Import := { module := `AgenticDS.Stats }
  let env ← importModules #[i] {}
  let (r, _) ← (collectAxioms n : CoreM _).toIO
    { fileName := "", fileMap := default } { env }
  pure r.toList

def m1v07_names : List Name :=
  [`AgenticDS.mean_const, `AgenticDS.variance_shift]

def m1v07 : IO Unit := do
  for n in m1v07_names do
    let a ← m1v07_axioms n
    IO.println s!"{n} depends on axioms: {a}"
