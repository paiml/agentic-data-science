import AgenticDS.Plot
/-! A planted fault: 14 rows overflow the picture, and an empty
chart has no bars; writeSvg must refuse both (exit=1). -/
open AgenticDS

def main (args : List String) : IO UInt32 := do
  let rows := (List.range 14).map fun i => (s!"r{i}", i + 1)
  let which := args.headD "tall"
  let rs := if which == "empty" then [] else rows
  writeSvg "planted.svg" "planted" 14 rs
  IO.println "NOT REFUSED"
  pure 0
