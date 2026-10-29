import AgenticDS
open AgenticDS Lean
-- The normal equations and the residual lemmas.
#check @ols_normal_equations
#check @resid_sum
#check @resid_x_sum
#eval show CoreM Unit from do
  let ax ← collectAxioms ``AgenticDS.ols_normal_equations
  if ax.contains ``sorryAx then throwError "sorry found"
  else IO.println s!"\x1b[1;32mcontract: ads-lean-e-m2-v03 OK\x1b[0m"
