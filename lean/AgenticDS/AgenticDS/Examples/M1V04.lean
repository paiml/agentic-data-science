import Mathlib
import AgenticDS.Examples.Run
/-! Why the gate counts the unfinished-proof word. -/

-- The compiler only warns about an unfinished proof,
-- so the gate also scans every source for the word,
-- for native-code proofs and for unfinished-work markers.
-- The gate runs that scan: make gate-lean.
def m1v04 : IO Unit := do
  let g ← IO.FS.readFile "../../scripts/gate-lean.sh"
  contract "ads-lean-m1v04-v1" ("SATD".isInfixOf g)
