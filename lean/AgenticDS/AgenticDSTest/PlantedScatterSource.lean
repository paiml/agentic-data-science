import AgenticDS.Plot
/-! A planted fault: the plotted points are not the source rows
(swapped axes, or a wrong row); writeScatter must refuse both
with plot_scatter_source (exit=1). -/
open AgenticDS

def main (args : List String) : IO UInt32 := do
  let src : List (Float × Float) := [(1, 2), (3, 5), (4, 4)]
  let pts : List (Float × Float) :=
    if args.headD "swap" == "swap" then src.map fun p => (p.2, p.1)
    else [(1, 2), (3, 5), (4, 3)]
  writeScatter "planted.svg" "planted" "x" "y" pts [] [] [] src
  IO.println "NOT REFUSED"
  pure 0
