import AgenticDS
open AgenticDS Lean
-- Nearest centroid: a tie goes to the lowest index.
#print minCost
#print nearestIdx
#eval nearestIdx (wdist [1, 1]) [1, 0] [[0, 0], [2, 0]]
#eval show CoreM Unit from do
  let ax ← collectAxioms ``AgenticDS.minCost_le
  if ax.contains ``sorryAx then throwError "sorry found"
  else IO.println s!"\x1b[1;32mcontract: ads-lean-e-m3-v02 OK\x1b[0m"
