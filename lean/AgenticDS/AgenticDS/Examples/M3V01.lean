import AgenticDS.Examples.Run
import AgenticDS.Tree
import AgenticDS.Kmeans
import AgenticDS.Examples.Scat
/-! Tour of the three new files. -/
-- Module 3 adds three small files, one job each.
-- Count their lines with wc yourself.
def m3v01_files : List String :=
  ["Kmeans", "Confusion", "Tree"]

def m3v01 : IO Unit := do
  penguinDemo "plot-m3v01.svg" "Penguins: flipper and mass"
    "flipper_length_mm" "body_mass_g" 4
  contract "ads-lean-m3v01-v1"
    (← plotOk "plot-m3v01.svg")
