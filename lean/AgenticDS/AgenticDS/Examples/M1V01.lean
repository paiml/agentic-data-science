import AgenticDS.Stats
import AgenticDS.Plot
/-! Tour: mean and variance for any field. -/
open AgenticDS

-- Tour: mean and variance, written for any field.
def m1v01_xs : List ℚ := [2, 4, 4, 4, 5, 5, 7, 9]


-- Csv reads the file, Stats holds the maths,
-- Profile joins them. List the files with ls.
def m1v01 : IO Unit := do
  IO.println s!"mean     = {mean m1v01_xs}"
  IO.println s!"variance = {variance m1v01_xs}"
  let pts := m1v01_xs.zipIdx.map fun (v, i) =>
    (i.toFloat, qf v)
  let m := qf (mean m1v01_xs)
  writeScatterDerived
    "plot-m1v01.svg" "Values and their mean"
    "position in list" "value" pts [(0, m), (7, m)] []
    [s!"mean     = {mean m1v01_xs}",
     s!"variance = {variance m1v01_xs}"]
