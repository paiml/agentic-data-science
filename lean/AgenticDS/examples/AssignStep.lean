import AgenticDS
open AgenticDS Lean
-- The assignment step can never do worse.
#check @minCost_le
#check @assign_step_optimal
#eval show CoreM Unit from do
  let ax ← collectAxioms ``AgenticDS.assign_step_optimal
  if ax.contains ``sorryAx then throwError "sorry found"
  else IO.println s!"\x1b[1;32mcontract: ads-lean-e-m3-v03 OK\x1b[0m"
