import AgenticDS.Tree
import AgenticDS.Kmeans
/-! Tour of the three new files. -/
-- Set 3 adds three small files, one job each.
-- The terminal counts their lines with wc itself.
def s3v01_files : List String :=
  ["Kmeans", "Confusion", "Tree"]

def s3v01 : IO Unit := pure ()
