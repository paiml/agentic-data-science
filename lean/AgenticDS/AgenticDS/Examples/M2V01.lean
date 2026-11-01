import Mathlib
import AgenticDS.Examples.Run
/-! Tour: list the sources, then head one file. -/

-- You list the package sources with ls, then
-- show the head of Regression.lean (after the licence).
def m2v01 : IO Unit := do
  let r ← IO.FS.readFile "AgenticDS/Regression.lean"
  contract "ads-lean-m2v01-v1" ("def olsSlope".isInfixOf r)
