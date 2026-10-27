import Mathlib
/-! The P3 golden values copied from R. -/
open Lean
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
  let acc ← IO.ofExcept
    (j.getObjValAs? JsonNumber "accuracy")
  IO.println s!"accuracy: {m3v08_exact conf} golden {acc}"
