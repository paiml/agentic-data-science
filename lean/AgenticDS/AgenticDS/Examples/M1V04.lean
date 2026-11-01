import AgenticDS.Examples.M1Data
/-! Why the gate counts the unfinished-proof word. -/

-- The compiler only warns about an unfinished proof,
-- so the gate also scans every source for the word,
-- for native-code proofs and for unfinished-work markers.
-- The gate runs that scan: make gate-lean.
def m1v04 : IO Unit := do
  -- Real data: the gate scan run over every example source.
  -- Plotted: lines in the file (x) against banned words found (y).
  let fs ← AgenticDS.leanFiles "AgenticDS/Examples"
  let ts ← fs.mapM fun f => IO.FS.readFile f
  let ps := ts.map fun t =>
    ((AgenticDS.nLines t).toFloat, (AgenticDS.hits t).toFloat)
  let h := (ts.map AgenticDS.hits).sum
  IO.println s!"scanned {fs.length} files, {h} markers"
  AgenticDS.writeScatter "plot-m1v04.svg"
    "Gate scan of the examples"
    "lines in the file" "banned words found" ps [] []
    [s!"scanned {fs.length} files", s!"{h} banned words"]
