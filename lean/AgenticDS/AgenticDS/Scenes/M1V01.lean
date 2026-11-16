import AgenticDS.Stats
/-! Tour: mean and variance for any field. -/
open AgenticDS

-- Tour: mean and variance, written for any field.
def s1v01_xs : List ℚ := [2, 4, 4, 4, 5, 5, 7, 9]

-- Csv reads the file, Stats holds the maths,
-- Profile joins them. The terminal lists the files.
def s1v01 : IO Unit := do
  IO.println s!"mean     = {mean s1v01_xs}"
  IO.println s!"variance = {variance s1v01_xs}"
