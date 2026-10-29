import AgenticDS
open AgenticDS Lean
-- Everything the gate counts for module 2.
#print axioms resid_sum
#print axioms resid_x_sum
#print axioms ols_normal_equations
#eval show CoreM Unit from do
  let ax ← collectAxioms ``AgenticDS.ols_normal_equations
  if ax.contains ``sorryAx then throwError "sorry found"
  else IO.println s!"\x1b[1;32mcontract: ads-lean-e-m2-v10 OK\x1b[0m"
