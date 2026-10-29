import AgenticDS
open AgenticDS Lean
-- Three species, and every sample lands in exactly one cell.
#print Species
#eval Species.all
#eval confusion [(Species.adelie, .adelie), (.gentoo, .adelie)] .gentoo .adelie
#check @confusion_total
#eval show CoreM Unit from do
  let ax ← collectAxioms ``AgenticDS.confusion_total
  if ax.contains ``sorryAx then throwError "sorry found"
  else IO.println s!"\x1b[1;32mcontract: ads-lean-e-m3-v04 OK\x1b[0m"
