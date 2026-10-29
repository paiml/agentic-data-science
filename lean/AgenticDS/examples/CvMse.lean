import AgenticDS
open AgenticDS Lean
-- Cross-validated error is computed exactly.
#eval cvMse ([(1, 3), (2, 6), (3, 7), (4, 11)] : List (ℚ × ℚ)) [0, 1, 0, 1] 2
#eval show CoreM Unit from do
  let ax ← collectAxioms ``AgenticDS.resid_sum
  if ax.contains ``sorryAx then throwError "sorry found"
  else IO.println s!"\x1b[1;32mcontract: ads-lean-e-m2-v08 OK\x1b[0m"
