import AgenticDS.Plot
/-! A planted fault: the plotted points are not the source rows
(swapped axes, a wrong row, a missing row or an extra row);
writeScatter must refuse each with plot_scatter_source (exit=1). -/
open AgenticDS

def main (args : List String) : IO UInt32 := do
  let src : List (Float × Float) := [(1, 2), (3, 5), (4, 4)]
  let pts : List (Float × Float) :=
    match args.headD "swap" with
    | "swap" => src.map fun p => (p.2, p.1)
    | "row" => [(1, 2), (3, 5), (4, 3)]
    | "missing" => src.take 2
    | _ => src ++ [(5, 5)]
  writeScatter "planted.svg" "planted" "x" "y" pts [] [] [] src
  IO.println "NOT REFUSED"
  pure 0
