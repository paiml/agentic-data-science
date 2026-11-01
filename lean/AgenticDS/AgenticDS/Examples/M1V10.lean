import Mathlib
import AgenticDS.Examples.Run
/-! Recap: the two examples. -/

-- Recap: the two examples this module ships.
-- List them: ls examples
def m1v10 : IO Unit := do
  let es ← System.FilePath.readDir "examples"
  contract "ads-lean-m1v10-v1" (es.size == 2)
