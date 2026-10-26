import AgenticDS.Scenes.M4

/-! Module 4 scene checks: registry, shape, every scene runs. -/

def main (_ : List String) : IO UInt32 := do
  if scenesM4.isEmpty then
    IO.println "scenes-m4: none yet (lands in its own PR)"
    return 0
  let (files, faults) ← moduleShape 4
  let mut ok := faults.isEmpty
  for f in faults do IO.eprintln s!"FAIL {f}"
  if files != scenesM4.length then
    IO.eprintln s!"FAIL {files} files, {scenesM4.length} scenes"
    ok := false
  for (id, act) in scenesM4 do
    try act catch e => IO.eprintln s!"FAIL {id}: {e}"; ok := false
  if ok then IO.println "contract: ads-lean-scenes-m4-v1 OK"
  pure (if ok then 0 else 1)
