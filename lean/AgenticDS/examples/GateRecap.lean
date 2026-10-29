import AgenticDS
open AgenticDS Lean
-- Everything the gate counts for module 3.
#print axioms assign_step_optimal
#print axioms minCost_le
#print axioms confusion_total
#eval show CoreM Unit from do
  let ax ← collectAxioms ``AgenticDS.assign_step_optimal
  if ax.contains ``sorryAx then throwError "sorry found"
  else IO.println s!"\x1b[1;32mcontract: ads-lean-e-m3-v10 OK\x1b[0m"
