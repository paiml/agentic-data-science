import AgenticDS.Scenes.M3V08
/-! The gate on the module commit; exact accuracy. -/
open Lean
-- The terminal runs make gate-lean: its four stages.

-- Accuracy: matrix trace over matrix sum, from the file.
def m3v10 : IO Unit := do
  let s ← IO.FS.readFile
    "../../datasets/golden/p3.json"
  let m ← IO.ofExcept (Json.parse s >>=
    (·.getObjValAs? (List (List Nat)) "confusion"))
  let tr := (List.range m.length).map fun i => (m[i]!)[i]!
  IO.println s!"trace {tr.sum} of {(m.map List.sum).sum}"
  IO.println s!"accuracy {m3v08_exact m}"
