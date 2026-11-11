import AgenticDS.Examples.Run
import AgenticDS.Kmeans
import AgenticDS.Plot
/-! The assignment step never does worse. -/
open AgenticDS
-- Any assignment f costs at least the nearest-centroid
-- objective: that assignment is never beaten.
theorem m3v03_step (d : ℚ → ℚ → ℚ) (c0 : ℚ)
    (cs ps : List ℚ) (f : ℚ → ℚ)
    (hf : ∀ p ∈ ps, f p ∈ c0 :: cs) :
    objective d ps c0 cs
      ≤ (ps.map fun p => d p (f p)).sum := by
  unfold objective
  apply List.sum_le_sum
  intro p hp
  exact minCost_le d p c0 cs (hf p hp)

def m3v03_d (p c : ℚ) : ℚ := (p - c) ^ 2

def m3v03 : IO Unit := do
  let ps : List ℚ := [0, 1, 5, 6]
  let best := objective m3v03_d ps 0 [6]
  let other := (ps.map fun p => m3v03_d p 0).sum
  IO.println s!"nearest centroid: {best}"
  IO.println s!"everyone to 0:    {other}"
  IO.println s!"never beaten: {decide (best ≤ other)}"
  let cost := fun (i : Nat) =>
    (i.toFloat / 2, qf (minCost m3v03_d (i / 2 : ℚ) 0 [6]))
  let cs := (List.range 13).map cost
  writeScatterDerived
    "plot-m3v03.svg" "Cost to the nearest centroid"
    "point position" "squared distance" cs cs
    (ps.map fun p => (qf p, qf (minCost m3v03_d p 0 [6])))
    [s!"centroids 0 and 6, total {best}"]
  contract "ads-lean-m3v03-v1"
    (decide (best ≤ other) && (← plotOk "plot-m3v03.svg"))
