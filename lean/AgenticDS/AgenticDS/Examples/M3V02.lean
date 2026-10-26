import AgenticDS.Kmeans
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
