import AgenticDS.Examples.M3
import AgenticDS.Kmeans
import AgenticDS.Tree
import AgenticDS.Confusion

/-! Module 3 example checks: registry, every example runs, and
the exact values the examples state. -/

open AgenticDS Lean
set_option linter.hashCommand false

-- V02: objective, nearest centroid with ties to the lowest index.
#guard minCost m3v02_d 2 0 [6] = 4
#guard objective m3v02_d [0, 1, 5, 6] 0 [6] = 2
#guard nearestIdx [9, 9, 9409] = 0
#guard nearestIdx [9, 4, 4] = 1
#guard wdist [1 / 4] [0] [2] = 1
-- V03: the nearest centroid beats any other assignment.
#guard objective m3v03_d [0, 1, 5, 6] 0 [6] = 2
#guard (([0, 1, 5, 6] : List ℚ).map fun p => m3v03_d p 0).sum = 62
-- V04: three species, and every sample lands in one cell.
#guard Species.all.length = 3
#guard confusion
  [(Species.adelie, .adelie), (.gentoo, .adelie)]
  .gentoo .adelie = 1
-- V06: deviance and best split.
#guard dev m3v06_rows = 3
#guard dev (m3v06_rows.take 3) = 0
#guard dev [] = 0
#guard bestSplit 1 m3v06_rows = some (0, 40)
#guard bestSplit 4 m3v06_rows = none
-- V07: pruning collapses the outlier subtree.
#guard (grow 1 5 m3v07_rows).leaves = 4
#guard errs (grow 1 5 m3v07_rows) m3v07_rows = 0
#guard (prune 2 m3v07_rows (grow 1 5 m3v07_rows)).leaves = 2
#guard errs (prune 2 m3v07_rows (grow 1 5 m3v07_rows))
  m3v07_rows = 1
#guard (fitTree 1 5 m3v07_rows).leaves = 4
-- V08, V09, V10: golden values.
def goldC : List (List Nat) :=
  [[37, 0, 0], [0, 16, 1], [0, 1, 30]]
#guard (goldC.map List.sum).sum = 85
#guard m3v08_exact goldC = 83 / 85
#guard m3v09_mutate "[37, 0, 0]" = "[36, 1, 0]"

def golden : IO String :=
  IO.FS.readFile "../../datasets/golden/p3.json"

/-- Runtime checks; each failure names itself. -/
def runtimeFaults : IO (List String) := do
  let mut bad : List String := []
  -- V08: the file holds the golden matrix, sizes and accuracy.
  let s ← golden
  let j ← IO.ofExcept (Json.parse s)
  let conf ← IO.ofExcept
    (j.getObjValAs? (List (List Nat)) "confusion")
  if conf != goldC then bad := bad ++ ["v08 confusion"]
  let km ← IO.ofExcept (j.getObjVal? "kmeans")
  let sz ← IO.ofExcept
    (km.getObjValAs? (List Nat) "cluster_sizes")
  if sz != [133, 123, 86] then bad := bad ++ ["v08 cluster sizes"]
  let acc ← IO.ofExcept (j.getObjValAs? JsonNumber "accuracy")
  let a : ℚ := (acc.mantissa : ℚ) / ((10 ^ acc.exponent : ℕ) : ℚ)
  let diff := if a < 83 / 85 then 83 / 85 - a else a - 83 / 85
  if m3v08_exact conf != 83 / 85 || diff > 1 / 1000000000 then
    bad := bad ++ ["v08 accuracy"]
  -- V09: the mutant differs from the golden matrix.
  let m ← IO.ofExcept (m3v09_matrix (m3v09_mutate s))
  if m != [[36, 1, 0], [0, 16, 1], [0, 1, 30]] then
    bad := bad ++ ["v09 mutant matrix"]
  if m == conf then bad := bad ++ ["v09 mutant not caught"]
  pure bad

def main (_ : List String) : IO UInt32 := do
  let dir : System.FilePath := "AgenticDS/Examples"
  let files := ((← dir.readDir).filter
    fun e => e.fileName.startsWith "M3V").size
  let mut ok := true
  if files != examplesM3.length then
    IO.eprintln s!"FAIL {files} files, {examplesM3.length} examples"
    ok := false
  for (id, act) in examplesM3 do
    -- v09 is the planted mismatch: it must fail, the rest must not.
    let failed ← try act; pure false catch _ => pure true
    if failed != (id == "v09") then
      IO.eprintln s!"FAIL {id}: wrong outcome"; ok := false
  for f in (← runtimeFaults) do
    IO.eprintln s!"FAIL {f}"
    ok := false
  if ok then IO.println "contract: ads-lean-examples-m3-v1 OK"
  pure (if ok then 0 else 1)
