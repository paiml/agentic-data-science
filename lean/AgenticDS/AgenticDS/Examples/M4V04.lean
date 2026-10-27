import AgenticDS.Pipeline
/-! clean_sub and clean_complete pin clean down exactly. -/
open AgenticDS
-- v is kept iff some input row validates to it.
theorem m4v04_iff (rs : List WineRaw) (v : ValidRow) :
    v ∈ clean rs ↔ ∃ r ∈ rs, validate r = some v :=
  ⟨clean_sub rs v, fun ⟨r, hr, hv⟩ =>
    clean_complete rs r v hr hv⟩
def m4v04 : IO Unit := do
  let names := [``clean_length_le, ``clean_sub,
    ``clean_complete, ``clean_in_range]
  for n in names do IO.println n.getString!
