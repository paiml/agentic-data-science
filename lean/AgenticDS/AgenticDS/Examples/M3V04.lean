import AgenticDS.Confusion
/-! Species and the confusion total. -/
open AgenticDS
-- Species is finite: Species.all lists its three values.
-- Summing every cell of the matrix gives the sample count.
theorem m3v04_total (ps : List (Species × Species)) :
    ∑ a, ∑ p, confusion ps a p = ps.length :=
  confusion_total ps

def m3v04 : IO Unit := do
  let ps : List (Species × Species) :=
    [(.adelie, .adelie), (.adelie, .adelie),
     (.gentoo, .gentoo), (.chinstrap, .gentoo),
     (.chinstrap, .chinstrap)]
  IO.println s!"species: {Species.all.length}"
  for a in Species.all do
    IO.println (Species.all.map fun p => confusion ps a p)
  let sum := (Species.all.map fun a =>
    (Species.all.map fun p => confusion ps a p).sum).sum
  IO.println s!"sum {sum}, length {ps.length}"
