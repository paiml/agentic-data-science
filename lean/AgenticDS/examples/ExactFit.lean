import AgenticDS
open AgenticDS Lean
-- Exact arithmetic: fractions, not floats.
#eval olsSlope ([(1, 3), (2, 5), (4, 8)] : List (ℚ × ℚ))
#eval olsIntercept ([(1, 3), (2, 5), (4, 8)] : List (ℚ × ℚ))
#eval show CoreM Unit from do
  let ax ← collectAxioms ``AgenticDS.resid_sum
  if ax.contains ``sorryAx then throwError "sorry found"
  else IO.println s!"\x1b[1;32mcontract: ads-lean-e-m2-v06 OK\x1b[0m"
