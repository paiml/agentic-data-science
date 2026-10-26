import AgenticDS.Scenes.M4

/-! Module 4 scene checks: registry, shape, every scene runs, and
the exact values the narration states. -/

open AgenticDS

-- Compile-time facts the narration states.
#guard (trainRows (List.range 6497)).length == 5198
#guard (testRows (List.range 6497)).length == 1299
#guard testRows (List.range 15) == [4, 9, 14]
#guard m4v07_sol == some [4 / 5, 7 / 5]
#guard m4v02_row.features.length == 11
#guard (validate ⟨m4v03_f, some 11, "red"⟩).isNone
#guard (validate ⟨m4v03_f, some 10, "white"⟩).isSome
#guard (validate ⟨m4v03_f, some 6, "rose"⟩).isNone
#guard (validate ⟨m4v03_f.tail, some 6, "red"⟩).isNone
#guard (m4v06_leak (List.range 5)).length == 5

/-- Output of a scene, captured. -/
def outOf (act : IO Unit) : IO String := do
  let (out, _) ← IO.FS.withIsolatedStreams act
  pure out

def lines (s : String) : List String :=
  (s.splitOn "\n").filter (· ≠ "")

def has (s sub : String) : Bool := (s.splitOn sub).length > 1

/-- Exact output of the scenes whose output is fixed. -/
def exact : List (String × List String) := [
  ("v02", ["features 11", "quality 6", "white false"]),
  ("v03", ["true", "false", "false", "false", "false",
    "kept 1 of 5"]),
  ("v04", ["clean_length_le", "clean_sub", "clean_complete",
    "clean_in_range"]),
  ("v05", ["test rows [4, 9, 14]", "clean 6497", "test 1299",
    "train 5198"]),
  ("v06", ["rows 5", "leaky train 5", "test 1"]),
  ("v07", ["(some [4/5, 7/5])"])]

def main (_ : List String) : IO UInt32 := do
  let (files, faults) ← moduleShape 4
  let mut ok := faults.isEmpty
  for f in faults do IO.eprintln s!"FAIL {f}"
  if files != scenesM4.length then
    IO.eprintln s!"FAIL {files} files, {scenesM4.length} scenes"
    ok := false
  let mut outs : List (String × String) := []
  for (id, act) in scenesM4 do
    try outs := outs ++ [(id, ← outOf act)]
    catch e => IO.eprintln s!"FAIL {id}: {e}"; ok := false
  let get := fun id => (outs.lookup id).getD ""
  for (id, want) in exact do
    if lines (get id) != want then
      IO.eprintln s!"FAIL {id} output: {lines (get id)}"
      ok := false
  -- v08: the golden file and the pipeline numbers agree.
  let v8 := get "v08"
  let want8 := ["\"n_rows\": 6497", "\"n_train\": 5198",
    "\"n_test\": 1299", "n_rows 6497", "n_train 5198",
    "n_test 1299", "rmse 0.7602", "r2 0.2598", "red 5.636",
    "white 5.877"]
  for w in want8 do
    unless has v8 w do
      IO.eprintln s!"FAIL v08 lacks {w}"; ok := false
  -- v01: the declarations the terminal greps, in file order.
  let want1 := ["structure WineRaw", "structure ValidRow",
    "def validate", "def clean",
    "theorem clean_length_le", "theorem clean_sub",
    "theorem clean_complete", "theorem clean_in_range",
    "def isTest", "def trainRows", "def testRows",
    "theorem length_filter_split",
    "theorem split_partition", "def design",
    "def gaussSolve", "def fitCoefs", "def predictRow",
    "def sseRows", "def sstRows", "def readWine"]
  let pl ← IO.FS.readFile "AgenticDS/Pipeline.lean"
  let decls := (lines pl).filterMap fun l =>
    match l.splitOn " " with
    | k :: n :: _ =>
      if ["structure", "def", "theorem"].contains k
      then some s!"{k} {n}" else none
    | _ => none
  if decls != want1 then
    IO.eprintln s!"FAIL v01 decls: {decls}"; ok := false
  -- v09: the timing line, and four tolerance lines in the test.
  let t4 ← IO.FS.readFile "AgenticDSTest/P4.lean"
  let tol := (lines t4).filter (has · "1000000")
  let head9 := (lines (get "v09")).headD ""
  unless tol.length == 4 && head9.startsWith "pipeline ms " do
    IO.eprintln s!"FAIL v09 output: {get "v09"}"; ok := false
  -- The camera types the native commands of demos/e-m4/scenes.spec,
  -- each followed by its own `echo "exit=$?"`; gate-lean.sh replays
  -- and checks that spec. Here: every scene has a block in it.
  let spec ← IO.FS.readFile "../../demos/e-m4/scenes.spec"
  for (id, _) in scenesM4 do
    unless has spec s!"\n== {id}\n" do
      IO.eprintln s!"FAIL spec lacks scene {id}"; ok := false
  if ok then IO.println "contract: ads-lean-scenes-m4-v1 OK"
  pure (if ok then 0 else 1)
