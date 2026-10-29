import AgenticDS
open AgenticDS Lean
-- No sorry anywhere in the module.
#print axioms ols_normal_equations
#print axioms ols_residuals_sum_zero_real
#eval show CoreM Unit from do
  let ax ← collectAxioms ``AgenticDS.ols_normal_equations
  if ax.contains ``sorryAx then throwError "sorry found"
  else IO.println s!"\x1b[1;32mcontract: ads-lean-e-m2-v07 OK\x1b[0m"
