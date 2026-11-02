import AgenticDS.Examples.Run
import AgenticDS.Kmeans
import AgenticDS.Plot
/-! The k-means objective and nearest centroid. -/
open AgenticDS
-- Squared distance, one dimension.
def m3v02_d (p c : ℚ) : ℚ := (p - c) ^ 2

-- minCost folds min; objective sums it. nearestIdx uses
-- strict <, so a tie keeps the lower index.
def m3v02 : IO Unit := do
  let ps : List ℚ := [0, 1, 5, 6]
  IO.println s!"minCost 2: {minCost m3v02_d 2 0 [6]}"
  IO.println s!"objective: {objective m3v02_d ps 0 [6]}"
  -- point 3 is equidistant from centroids 0 and 6
  let tie := [m3v02_d 3 0, m3v02_d 3 6, m3v02_d 3 100]
  IO.println s!"tie costs {tie}: idx {nearestIdx tie}"
  IO.println s!"later best: idx {nearestIdx [9, 4, 4]}"
  -- weights 1 / variance give the z-scored distance
  IO.println s!"wdist: {wdist [1 / 4] [0] [2]}"
  let cost := fun (i : Nat) =>
    (i.toFloat / 2, qf (objective m3v02_d ps (i / 2 : ℚ) []))
  let cs := (List.range 13).map cost
  writeScatter "plot-m3v02.svg" "Objective by centroid choice"
    "centroid position" "sum of squared distances" cs cs []
    [s!"best centroid 3: {objective m3v02_d ps 3 []}"]
    cs
  contract "ads-lean-m3v02-v1"
    (decide (objective m3v02_d ps 0 [6] ≤
      objective m3v02_d ps 3 []) &&
      (← plotOk "plot-m3v02.svg"))
