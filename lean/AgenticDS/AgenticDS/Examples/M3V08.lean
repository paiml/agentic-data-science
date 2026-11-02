import AgenticDS.Examples.Run
import Mathlib
import AgenticDS.Plot
import AgenticDS.Examples.Scat
/-! The P3 golden values copied from R. -/
open Lean AgenticDS
def m3v08_load : IO Json := do
  IO.ofExcept (Json.parse (← IO.FS.readFile
    "../../datasets/golden/p3.json"))
-- Exact accuracy from the file's matrix: trace over the
-- sum of every cell, no Float, no typed-in number.
def m3v08_exact (c : List (List Nat)) : ℚ :=
  ((c.zipIdx.map fun p => p.1[p.2]!).sum : ℕ) /
    (c.map List.sum).sum
def m3v08 : IO Unit := do
  let j ← m3v08_load
  let conf ← IO.ofExcept
    (j.getObjValAs? (List (List Nat)) "confusion")
  IO.println s!"file confusion: {conf}"
  let km ← IO.ofExcept (j.getObjVal? "kmeans")
  let sz ← IO.ofExcept
    (km.getObjValAs? (List Nat) "cluster_sizes")
  IO.println s!"cluster sizes: {sz}"
  let rows := sz.zipIdx.map fun (n, i) => (s!"cluster {i}", n)
  plot 30 rows
  writeSvg "plot-m3v08.svg" "Cluster sizes" 30 rows
  let acc ← IO.ofExcept
    (j.getObjValAs? JsonNumber "accuracy")
  IO.println s!"accuracy: {m3v08_exact conf} golden {acc}"
  penguinDemo "plot-m3v08b.svg" "Penguins: bill length and flipper"
    "bill_length_mm" "flipper_length_mm" 4
  contract "ads-lean-m3v08-v1"
    (sz.sum > 0 && (← plotOk "plot-m3v08.svg") &&
      (← plotOk "plot-m3v08b.svg"))
