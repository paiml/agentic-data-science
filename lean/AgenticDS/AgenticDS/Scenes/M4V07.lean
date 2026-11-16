import AgenticDS.Pipeline
/-! gaussSolve: exact Gauss-Jordan elimination over ℚ. -/
open AgenticDS
-- The 2x2 system [[2,1],[1,3]] x = [3,5].
def s4v07_sol : Option (List ℚ) :=
  gaussSolve [[2, 1], [1, 3]] [3, 5]
-- Exact fractions, no 0.8 and 1.4 with noise.
theorem s4v07_exact : s4v07_sol = some [4 / 5, 7 / 5] := by
  decide +kernel
def s4v07 : IO Unit := do
  IO.println s!"{s4v07_sol}"
