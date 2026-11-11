import AgenticDS.Examples.Run
import AgenticDS.Pipeline
/-! A ValidRow is built only from both proofs. -/
open AgenticDS
def m4v02_row : ValidRow :=
  ⟨List.replicate 11 1, 6, false, by simp, by norm_num⟩
-- So no ValidRow has ten features ...
theorem m4v02_ten (r : ValidRow) :
    r.features.length ≠ 10 := by
  rw [r.h_len]; omega
-- ... and none has quality eleven.
theorem m4v02_q (r : ValidRow) : r.quality ≠ 11 := by
  have := r.h_q.2; intro h; rw [h] at this
  norm_num at this
def m4v02 : IO Unit := do
  IO.println s!"features {m4v02_row.features.length}"
  IO.println s!"quality {m4v02_row.quality}"
  IO.println s!"white {m4v02_row.white}"
  let f : List (Option ℚ) := List.replicate 11 (some 1)
  let ok := (validate ⟨f, some 6, "red"⟩).map
    (·.features.length)
  contract "ads-lean-m4v02-v1"
    (ok == some 11 &&
      (validate ⟨f.tail, some 6, "red"⟩).isNone &&
      (validate ⟨f, some 11, "red"⟩).isNone)
