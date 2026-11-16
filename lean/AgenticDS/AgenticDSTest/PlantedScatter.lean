import AgenticDS.Plot
/-! A planted fault: an empty scatter and a point that is not a
number; writeScatter must refuse both (exit=1). -/
open AgenticDS

def main (args : List String) : IO UInt32 := do
  let bad : Float := 0 / 0
  let pts : List (Float × Float) :=
    if args.headD "empty" == "nan" then [(0, 0), (1, bad)] else []
  writeScatter "planted.svg" "planted" "x" "y" pts [] [] [] pts
  IO.println "NOT REFUSED"
  pure 0
