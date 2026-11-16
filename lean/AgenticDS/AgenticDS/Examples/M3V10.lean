import AgenticDS.Examples.Run
import AgenticDS.Examples.M3V08
import AgenticDS.Examples.Scat
/-! The gate on the module commit; exact accuracy. -/
open Lean
-- You run make gate-lean: its four stages.

-- Accuracy: matrix trace over matrix sum, from the file.
def m3v10 : IO Unit := do
  let s ← IO.FS.readFile
    "../../datasets/golden/p3.json"
  let m ← IO.ofExcept (Json.parse s >>=
    (·.getObjValAs? (List (List Nat)) "confusion"))
  let tr := (List.range m.length).map fun i => (m[i]!)[i]!
  IO.println s!"trace {tr.sum} of {(m.map List.sum).sum}"
  IO.println s!"accuracy {m3v08_exact m}"
  penguinDemo "plot-m3v10.svg" "Penguins: bill length and mass"
    "bill_length_mm" "body_mass_g" 4
  contract "ads-lean-m3v10-v1"
    (tr.sum == 83 && (m.map List.sum).sum == 85 &&
      m3v08_exact m == 83 / 85 &&
      (← plotOk "plot-m3v10.svg"))
