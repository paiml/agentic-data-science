import AgenticDS.Stats
import AgenticDS.Plot
/-! Tour: mean and variance for any field. -/
open AgenticDS

-- Tour: mean and variance, written for any field.
def m1v01_xs : List ℚ := [2, 4, 4, 4, 5, 5, 7, 9]

-- How many of the eight values equal each number.
def m1v01_hist : List (String × Nat) :=
  (List.range 10).map fun v =>
    (s!"{v}", (m1v01_xs.filter (· = (v : ℚ))).length)

-- Csv reads the file, Stats holds the maths,
-- Profile joins them. List the files with ls.
def m1v01 : IO Unit := do
  IO.println s!"mean     = {mean m1v01_xs}"
  IO.println s!"variance = {variance m1v01_xs}"
  plot 24 m1v01_hist
  writeSvg "plot-m1v01.svg" "Values in m1v01_xs" 24 m1v01_hist
