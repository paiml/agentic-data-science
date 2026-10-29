import AgenticDS
open AgenticDS Lean
-- Module 3: k-means, confusion matrices, CART.
#check @objective
#check @assign_step_optimal
#check @confusion_total
#check @fitTree
#eval show CoreM Unit from do
  let ax ← collectAxioms ``AgenticDS.assign_step_optimal
  if ax.contains ``sorryAx then throwError "sorry found"
  else IO.println s!"\x1b[1;32mcontract: ads-lean-e-m3-v01 OK\x1b[0m"
