import AgenticDS
open AgenticDS Lean
-- Decide is kernel computation; no native_decide, no sorry.
#eval decide (Species.adelie = Species.gentoo)
#print axioms confusion_total
#print axioms assign_step_optimal
#eval show CoreM Unit from do
  let ax ← collectAxioms ``AgenticDS.confusion_total
  if ax.contains ``sorryAx then throwError "sorry found"
  else IO.println s!"\x1b[1;32mcontract: ads-lean-e-m3-v05 OK\x1b[0m"
