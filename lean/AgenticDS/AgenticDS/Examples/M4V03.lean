import AgenticDS.Pipeline
/-! validate refuses a bad row; clean keeps the somes. -/
open AgenticDS
def m4v03_f : List (Option ℚ) := List.replicate 11 (some 1)
-- Quality eleven is refused, never clamped.
theorem m4v03_q11 :
    validate ⟨m4v03_f, some 11, "red"⟩ = none := by
  norm_num [validate, m4v03_f]
def m4v03 : IO Unit := do
  let rs : List WineRaw := [
    ⟨m4v03_f, some 6, "red"⟩,
    ⟨m4v03_f, some 11, "red"⟩,
    ⟨m4v03_f.tail, some 6, "red"⟩,
    ⟨none :: m4v03_f.tail, some 6, "white"⟩,
    ⟨m4v03_f, some 6, "rose"⟩]
  for r in rs do IO.println s!"{(validate r).isSome}"
  IO.println s!"kept {(clean rs).length} of {rs.length}"
