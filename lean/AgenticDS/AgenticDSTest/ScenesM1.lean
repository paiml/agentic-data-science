import AgenticDS.Scenes.M1

/-! Module 1 scene checks: registry, shape, values, every scene
runs. -/

open AgenticDS

#guard mean m1v01_xs == 5
#guard variance m1v01_xs == 4
#guard m1v02_third == 1
#guard m1v02_float == false

-- Lines each scene must print.
def m1Want : List (String × List String) := [
  ("v01", ["mean     = 5", "variance = 4"]),
  ("v03", ["leanprover/lean4:v4.35.0"])]

-- The camera types the native commands of demos/e-m1/scenes.spec,
-- each followed by its own `echo "exit=$?"`; gate-lean.sh replays
-- and checks that spec. Here: every scene has a block in it.
def specHas (spec id : String) : Bool :=
  (spec.splitOn s!"\n== {id}\n").length > 1

def main (_ : List String) : IO UInt32 := do
  let (files, faults) ← moduleShape 1
  let mut ok := faults.isEmpty
  for f in faults do IO.eprintln s!"FAIL {f}"
  if files != scenesM1.length then
    IO.eprintln s!"FAIL {files} files, {scenesM1.length} scenes"
    ok := false
  if (← m1v03_pin) != "leanprover/lean4:v4.35.0\n" then
    IO.eprintln "FAIL toolchain pin"
    ok := false
  let ax ← m1v07_axioms `AgenticDS.variance_shift
  if ax.contains `sorryAx || ax.length == 0 then
    IO.eprintln s!"FAIL axioms {ax}"
    ok := false
  let spec ← IO.FS.readFile "../../demos/e-m1/scenes.spec"
  for (id, _) in scenesM1 do
    unless specHas spec id do
      IO.eprintln s!"FAIL spec lacks scene {id}"; ok := false
  for (id, act) in scenesM1 do
    try
      let (out, _) ← IO.FS.withIsolatedStreams act
      let want := (m1Want.lookup id).getD []
      for w in want do
        unless (out.splitOn w).length > 1 do
          IO.eprintln s!"FAIL {id} lacks {w}"; ok := false
    catch e => IO.eprintln s!"FAIL {id}: {e}"; ok := false
  if ok then IO.println "contract: ads-lean-scenes-m1-v1 OK"
  pure (if ok then 0 else 1)
