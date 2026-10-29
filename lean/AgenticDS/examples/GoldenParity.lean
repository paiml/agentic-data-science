import AgenticDS
open AgenticDS Lean
def rows : List Row :=
  [([1, 1], .adelie), ([2, 1], .adelie), ([8, 9], .gentoo),
   ([9, 8], .gentoo), ([5, 5], .chinstrap)]
-- Confusion matrix and accuracy of the fitted tree.
def preds : List (Species × Species) :=
  rows.map fun r => (r.2, (fitTree rows).predict r.1)
#eval Species.all.map fun a => Species.all.map fun p => confusion preds a p
#eval (preds.filter fun q => q.1 == q.2).length
#eval show CoreM Unit from do
  let ax ← collectAxioms ``AgenticDS.confusion_total
  if ax.contains ``sorryAx then throwError "sorry found"
  else IO.println s!"\x1b[1;32mcontract: ads-lean-e-m3-v08 OK\x1b[0m"
