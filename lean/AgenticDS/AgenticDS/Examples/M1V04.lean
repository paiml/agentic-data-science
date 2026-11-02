import AgenticDS.Examples.M1Data
import AgenticDS.Examples.Run
/-! Why the gate counts the unfinished-proof word. -/

-- The compiler only warns about an unfinished proof,
-- so the gate also scans every source for the word,
-- for native-code proofs and for unfinished-work markers.
-- The gate runs that scan: make gate-lean.
def m1v04 : IO Unit := do
  -- Real data: the gate scan run over every example source.
  -- Plotted: lines in the file (x) against the non-blank
  -- lines the scan read (y). The banned-word total stays
  -- in the notes and the contract (it must be 0).
  let fs ← AgenticDS.leanFiles "AgenticDS/Examples"
  let ts ← fs.mapM fun f => IO.FS.readFile f
  let live := fun (l : String) =>
    l.toList.any fun c => !c.isWhitespace
  let ps := ts.map fun t =>
    ((AgenticDS.nLines t).toFloat,
     ((t.splitOn "\n").filter live).length.toFloat)
  let h := (ts.map AgenticDS.hits).sum
  IO.println s!"scanned {fs.length} files, {h} markers"
  AgenticDS.writeScatter "plot-m1v04.svg"
    "Gate scan of the examples"
    "lines in the file" "non-blank lines scanned" ps [] []
    [s!"scanned {fs.length} files", s!"{h} banned words"]
    ps
  contract "ads-lean-m1v04-v1" (fs.length > 0 && h == 0)
