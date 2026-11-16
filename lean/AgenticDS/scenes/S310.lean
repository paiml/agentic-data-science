/-
Copyright (c) 2026 Pragmatic AI Labs. All rights reserved.
Released under MIT license as described in the file LICENSE.
Authors: Pragmatic AI Labs
-/
/-! # Scene 3.1.0: three small files, one job each

Run from `lean/AgenticDS`: `lake env lean scenes/S310.lean`.
Provable contract: Kmeans, Confusion and Tree each read back
under 150 lines, and the total is their sum. Writes nothing. -/

/-- Line count of each module-3 file, then the total. -/
def sizes : IO Unit := do
  let fs := ["Kmeans", "Confusion", "Tree"]
  let mut ns : List Nat := []
  for f in fs do
    let n := (← IO.FS.lines s!"AgenticDS/{f}.lean").size
    IO.println s!"{n} {f}.lean"
    ns := ns ++ [n]
  let t := ns.foldl (· + ·) 0
  IO.println s!"{t} total"
  unless ns.all (· < 150) && ns.length == 3 && t > 0 do
    throw (IO.userError "contract ads-lean-s310-small-v1 violated")
  IO.println "contract: ads-lean-s310-small-v1 OK"

#eval sizes
