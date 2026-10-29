import AgenticDS
open AgenticDS Lean
def rows : List Row :=
  [([1, 1], .adelie), ([2, 1], .adelie), ([8, 9], .gentoo),
   ([9, 8], .gentoo), ([5, 5], .chinstrap)]
-- fitTree grows, then prunes at the cost-complexity cutoff.
#eval (fitTree rows).leaves
#eval errs (fitTree rows) rows
#eval show CoreM Unit from do
  let ax ← collectAxioms ``AgenticDS.assign_step_optimal
  if ax.contains ``sorryAx then throwError "sorry found"
  else IO.println s!"\x1b[1;32mcontract: ads-lean-e-m3-v07 OK\x1b[0m"
