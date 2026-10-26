import AgenticDS.Scenes.M3
import AgenticDS.Kmeans
import AgenticDS.Tree
import AgenticDS.Confusion

/-! Module 3 scene checks: registry, shape, every scene runs, and
the exact values the narration states. -/

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

-- The camera types the native commands of demos/e-m3/scenes.spec,
-- each followed by its own `echo "exit=$?"`; gate-lean.sh replays
-- and checks that spec. Here: every scene has a block in it.
def demoFaults : IO (List String) := do
  let spec ← IO.FS.readFile "../../demos/e-m3/scenes.spec"
  let ids := (List.range 10).map fun i =>
    s!"v{if i + 1 < 10 then "0" else ""}{i + 1}"
  pure <| ids.filterMap fun id =>
    if (spec.splitOn s!"\n== {id}\n").length > 1 then none
    else some s!"spec lacks scene {id}"

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
  let (files, faults) ← moduleShape 3
  let mut ok := faults.isEmpty
  for f in faults do IO.eprintln s!"FAIL {f}"
  if files != scenesM3.length then
    IO.eprintln s!"FAIL {files} files, {scenesM3.length} scenes"
    ok := false
  for (id, act) in scenesM3 do
    -- v09 is the planted mismatch: it must fail, the rest must not.
    let failed ← try act; pure false catch _ => pure true
    if failed != (id == "v09") then
      IO.eprintln s!"FAIL {id}: wrong outcome"; ok := false
  for f in (← demoFaults) ++ (← runtimeFaults) do
    IO.eprintln s!"FAIL {f}"
    ok := false
  if ok then IO.println "contract: ads-lean-scenes-m3-v1 OK"
  pure (if ok then 0 else 1)
