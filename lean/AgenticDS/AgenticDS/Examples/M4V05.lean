import AgenticDS.Pipeline
/-! Every fifth row is a test row; the parts add up. -/
open AgenticDS
-- The golden arithmetic: 6497 = 5198 + 1299.
theorem m4v05_golden :
    (trainRows (List.range 6497)).length +
      (testRows (List.range 6497)).length = 6497 :=
  (split_partition _).trans (List.length_range ..)
def m4v05 : IO Unit := do
  let l := List.range 6497
  IO.println s!"test rows {testRows (List.range 15)}"
  IO.println s!"clean {l.length}"
  IO.println s!"test {(testRows l).length}"
  IO.println s!"train {(trainRows l).length}"
