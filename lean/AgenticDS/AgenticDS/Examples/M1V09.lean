import Mathlib
import AgenticDS.Examples.Run
/-! The four gate checks. -/

-- The gate runs four checks; each one can fail:
--   1 build   warnings are errors
--   2 scan    no unfinished-proof or SATD markers
--   3 axioms  only propext, choice, Quot.sound
--   4 golden parity against the R numbers
-- The real gate: make gate-lean.
def m1v09 : IO Unit := do
  let g ← IO.FS.readFile "../../scripts/gate-lean.sh"
  contract "ads-lean-m1v09-v1"
    (["lake build", "SATD", "depends on axioms",
      "contract: ads-lean-p1-v1 OK"].all (·.isInfixOf g))
