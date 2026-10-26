import AgenticDS.Scenes.M2

/-! Module 2 scene checks: registry, shape, every scene runs. -/

def main (_ : List String) : IO UInt32 := do
  if scenesM2.isEmpty then
    IO.println "scenes-m2: none yet (lands in its own PR)"
    return 0
  let (files, faults) ← moduleShape 2
  let mut ok := faults.isEmpty
  for f in faults do IO.eprintln s!"FAIL {f}"
  if files != scenesM2.length then
    IO.eprintln s!"FAIL {files} files, {scenesM2.length} scenes"
    ok := false
  for (id, act) in scenesM2 do
    try act catch e => IO.eprintln s!"FAIL {id}: {e}"; ok := false
  if ok then IO.println "contract: ads-lean-scenes-m2-v1 OK"
  pure (if ok then 0 else 1)
