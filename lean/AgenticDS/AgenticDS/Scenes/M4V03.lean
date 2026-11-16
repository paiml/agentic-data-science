import AgenticDS.Pipeline
/-! validate refuses a bad row; clean keeps the somes. -/
open AgenticDS
def s4v03_f : List (Option ℚ) := List.replicate 11 (some 1)
-- Quality eleven is refused, never clamped.
theorem s4v03_q11 :
    validate ⟨s4v03_f, some 11, "red"⟩ = none := by
  norm_num [validate, s4v03_f]
def s4v03 : IO Unit := do
  let rs : List WineRaw := [
    ⟨s4v03_f, some 6, "red"⟩,
    ⟨s4v03_f, some 11, "red"⟩,
    ⟨s4v03_f.tail, some 6, "red"⟩,
    ⟨none :: s4v03_f.tail, some 6, "white"⟩,
    ⟨s4v03_f, some 6, "rose"⟩]
  for r in rs do IO.println s!"{(validate r).isSome}"
  IO.println s!"kept {(clean rs).length} of {rs.length}"
