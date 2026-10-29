import AgenticDS
open AgenticDS Lean
-- The five sums and the closed-form slope and intercept.
#print sx
#print olsSlope
#print olsIntercept
#eval olsSlope ([(0, 1), (1, 3), (2, 5)] : List (ℚ × ℚ))
#eval show CoreM Unit from do
  let ax ← collectAxioms ``AgenticDS.resid_x_sum
  if ax.contains ``sorryAx then throwError "sorry found"
  else IO.println s!"\x1b[1;32mcontract: ads-lean-e-m2-v02 OK\x1b[0m"
