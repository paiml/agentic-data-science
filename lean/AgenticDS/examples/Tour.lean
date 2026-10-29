import AgenticDS
open AgenticDS Lean
-- Tour: the regression library is statements next to definitions.
#check @olsSlope
#check @olsIntercept
#check @resid_sum
#check @ols_normal_equations
#eval show CoreM Unit from do
  let ax ← collectAxioms ``AgenticDS.resid_sum
  if ax.contains ``sorryAx then throwError "sorry found"
  else IO.println s!"\x1b[1;32mcontract: ads-lean-e-m2-v01 OK\x1b[0m"
