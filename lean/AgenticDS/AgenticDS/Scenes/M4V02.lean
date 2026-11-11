import AgenticDS.Pipeline
/-! A ValidRow is built only from both proofs. -/
open AgenticDS
def s4v02_row : ValidRow :=
  ⟨List.replicate 11 1, 6, false, by simp, by norm_num⟩
-- So no ValidRow has ten features ...
theorem s4v02_ten (r : ValidRow) :
    r.features.length ≠ 10 := by
  rw [r.h_len]; omega
-- ... and none has quality eleven.
theorem s4v02_q (r : ValidRow) : r.quality ≠ 11 := by
  have := r.h_q.2; intro h; rw [h] at this
  norm_num at this
def s4v02 : IO Unit := do
  IO.println s!"features {s4v02_row.features.length}"
  IO.println s!"quality {s4v02_row.quality}"
  IO.println s!"white {s4v02_row.white}"
