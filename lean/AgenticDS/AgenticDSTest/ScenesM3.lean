import AgenticDS.Scenes.M3

/-! Module 3 scene checks: registry, shape, every scene runs. -/

def main (_ : List String) : IO UInt32 := do
  if scenesM3.isEmpty then
    IO.println "scenes-m3: none yet (lands in its own PR)"
    return 0
  let (files, faults) ← moduleShape 3
  let mut ok := faults.isEmpty
  for f in faults do IO.eprintln s!"FAIL {f}"
  if files != scenesM3.length then
    IO.eprintln s!"FAIL {files} files, {scenesM3.length} scenes"
    ok := false
  for (id, act) in scenesM3 do
    try act catch e => IO.eprintln s!"FAIL {id}: {e}"; ok := false
  if ok then IO.println "contract: ads-lean-scenes-m3-v1 OK"
  pure (if ok then 0 else 1)
