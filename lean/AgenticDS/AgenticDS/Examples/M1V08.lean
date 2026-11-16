import AgenticDS.Examples.M1Data
/-! The contract and its falsifier. -/

-- The contract names what is promised and its falsifier.
def m1v08_path : String :=
  "../../contracts/ads-lean-p1-v1.yaml"

def m1v08 : IO Unit := do
  let ls := (← IO.FS.readFile m1v08_path).splitOn "\n"
  for l in ls.take 10 do IO.println (l.take 96)
  let fs := ls.filter (·.startsWith "  - id: FALSIFY")
  let n := fs.length
  IO.println s!"FALSIFY lines: {n}"
  -- Real data: the contract file, one point per line (its number
  -- against its width in characters).
  let ps := ls.zipIdx.map fun (l, i) =>
    ((i + 1).toFloat, l.length.toFloat)
  IO.println s!"{ls.length} lines in the contract file"
  AgenticDS.writeScatterDerived
    "plot-m1v08.svg" "The contract file"
    "line number" "characters in the line" ps [] []
    [s!"{ls.length} lines", s!"{n} FALSIFY ids"]
