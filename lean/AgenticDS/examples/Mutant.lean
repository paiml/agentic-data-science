import AgenticDS
open AgenticDS Lean
-- A guard that must hold; the mutant matrix is refused.
#guard confusion [(Species.adelie, Species.adelie)] .adelie .adelie == 1
#eval confusion [(Species.adelie, Species.adelie)] .adelie .adelie == 0
#eval show CoreM Unit from do
  let ax ← collectAxioms ``AgenticDS.confusion_total
  if ax.contains ``sorryAx then throwError "sorry found"
  else IO.println s!"\x1b[1;32mcontract: ads-lean-e-m3-v09 OK\x1b[0m"
