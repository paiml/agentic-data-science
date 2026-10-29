import AgenticDS
open AgenticDS Lean

-- The residuals for intercept 1 and slope 2 sum to Sy - n*1 - 2*Sx.
example (d : List (ℚ × ℚ)) :
    (d.map fun p => p.2 - 1 - 2 * p.1).sum = sy d - cnt d * 1 - 2 * sx d := by
  trace_state
  exact resid_sum d 1 2

-- Verdict: the theorem we just used rests on no sorry.
#eval show CoreM Unit from do
  let ax ← collectAxioms ``AgenticDS.resid_sum
  if ax.contains ``sorryAx then throwError "sorry found"
  else IO.println s!"\x1b[1;32mcontract: ads-lean-e-m2-v04 OK\x1b[0m"
