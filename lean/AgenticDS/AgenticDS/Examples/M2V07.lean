import Mathlib
import AgenticDS.Examples.Run
/-! The axiom report, then a scan for banned markers. -/

-- You print the axiom report with
-- `lake env lean scripts/AxiomsM2.lean`, then run the
-- gate's own marker scan.
def m2v07 : IO Unit := do
  let a ← IO.FS.readFile "scripts/AxiomsM2.lean"
  let g ← IO.FS.readFile "../../scripts/gate-lean.sh"
  contract "ads-lean-m2v07-v1"
    ("#print axioms".isInfixOf a && "SATD".isInfixOf g)
