import Mathlib
/-! The contract and its falsifier. -/

-- The contract names what is promised and its falsifier.
def s1v08_path : String :=
  "../../contracts/ads-lean-p1-v1.yaml"

def s1v08 : IO Unit := do
  let ls := (← IO.FS.readFile s1v08_path).splitOn "\n"
  for l in ls.take 10 do IO.println (l.take 96)
  let fs := ls.filter (·.startsWith "  - id: FALSIFY")
  let n := fs.length
  IO.println s!"FALSIFY lines: {n}"
