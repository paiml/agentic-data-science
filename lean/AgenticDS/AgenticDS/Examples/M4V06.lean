import AgenticDS.Pipeline
/-! The leak: train on every row, test rows included. -/
open AgenticDS
def m4v06_leak (l : List ℕ) : List ℕ :=
  l.zipIdx.map (·.1)
-- split_partition's statement is false for the leak.
theorem m4v06_fails : ¬ ∀ l : List ℕ,
    (m4v06_leak l).length + (testRows l).length
      = l.length := by
  intro h
  have := h (List.range 5)
  revert this
  simp [m4v06_leak, testRows, isTest, List.range_succ,
    List.zipIdx]
def m4v06 : IO Unit := do
  let l := List.range 5
  IO.println s!"rows {l.length}"
  IO.println s!"leaky train {(m4v06_leak l).length}"
  IO.println s!"test {(testRows l).length}"
