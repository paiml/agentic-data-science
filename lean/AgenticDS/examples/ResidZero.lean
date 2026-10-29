import AgenticDS
open AgenticDS Lean
-- Residuals sum to zero over the reals.
#check @ols_residuals_sum_zero_real
#eval show CoreM Unit from do
  let ax ← collectAxioms ``AgenticDS.ols_residuals_sum_zero_real
  if ax.contains ``sorryAx then throwError "sorry found"
  else IO.println s!"\x1b[1;32mcontract: ads-lean-e-m2-v05 OK\x1b[0m"
