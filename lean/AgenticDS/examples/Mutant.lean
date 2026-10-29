import AgenticDS
open AgenticDS Lean
-- Slope of y = 2x + 1 is 2; the mutant 5/2 is refused.
#guard olsSlope ([(0, 1), (1, 3), (2, 5)] : List (ℚ × ℚ)) == 2
#eval olsSlope ([(0, 1), (1, 3), (2, 5)] : List (ℚ × ℚ)) == 5/2
#eval show CoreM Unit from do
  let ax ← collectAxioms ``AgenticDS.resid_sum
  if ax.contains ``sorryAx then throwError "sorry found"
  else IO.println s!"\x1b[1;32mcontract: ads-lean-e-m2-v09 OK\x1b[0m"
