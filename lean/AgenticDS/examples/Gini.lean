import AgenticDS
open AgenticDS Lean
def rows : List Row :=
  [([1, 1], .adelie), ([2, 1], .adelie), ([8, 9], .gentoo),
   ([9, 8], .gentoo), ([5, 5], .chinstrap)]
-- Deviance of a node, and the best split found by search.
#eval dev rows
#eval dev [([1, 1], .adelie), ([2, 1], .adelie)]
#eval bestSplit rows 2 1
#eval show CoreM Unit from do
  let ax ← collectAxioms ``AgenticDS.minCost_le
  if ax.contains ``sorryAx then throwError "sorry found"
  else IO.println s!"\x1b[1;32mcontract: ads-lean-e-m3-v06 OK\x1b[0m"
