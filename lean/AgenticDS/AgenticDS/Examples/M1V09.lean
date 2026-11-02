import AgenticDS.Examples.M1Data
import AgenticDS.Examples.Run
/-! The four gate checks. -/

-- The gate runs four checks; each one can fail:
--   1 build   warnings are errors
--   2 scan    no unfinished-proof or SATD markers
--   3 axioms  only propext, choice, Quot.sound
--   4 golden parity against the R numbers
-- The real gate: make gate-lean.
def m1v09 : IO Unit := do
  -- Real data: how many items each check looks at. 1 build: the
  -- example sources; 2 scan: banned words found; 3 axioms: the
  -- theorems listed in scripts/Axioms.lean; 4 golden: the means
  -- held in datasets/golden/p1.json.
  let fs ← AgenticDS.leanFiles "AgenticDS/Examples"
  let ts ← fs.mapM fun f => IO.FS.readFile f
  let thms := ((← IO.FS.readFile "scripts/Axioms.lean").splitOn
    "#print axioms").length - 1
  let gold := ((← IO.FS.readFile
    "../../datasets/golden/p1.json").splitOn "\"mean\"").length - 1
  let ns := [fs.length, (ts.map AgenticDS.hits).sum, thms, gold]
  for (c, n) in ["build", "scan", "axioms", "golden"].zip ns do
    IO.println s!"check {c}: {n} items"
  let pts9 := ns.zipIdx.map fun (n, i) =>
    ((i + 1).toFloat, n.toFloat)
  AgenticDS.writeScatter "plot-m1v09.svg"
    "What each gate check reads"
    "check (1 build, 2 scan, 3 axioms, 4 golden)" "items"
    pts9 [] [] ["scan must find 0"] pts9
  contract "ads-lean-m1v09-v1"
    (fs.length > 0 && (ts.map AgenticDS.hits).sum == 0 &&
      thms > 0 && gold > 0)
