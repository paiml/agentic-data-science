import AgenticDS.Cv
import AgenticDS.Plot
/-! Exact penguins fit, golden numbers, parity. -/
open AgenticDS

-- You then run the example natively: the exact fit, the plot
-- of the data with the fitted line, and the parity test.
def m2v06 : IO Unit := do
  let d := flipperMass (← readCsv "../..")
  IO.println s!"slope: {olsSlope d}"
  IO.println s!"intercept: {olsIntercept d}"
  let a := olsIntercept d
  let b := olsSlope d
  textScatter 72 20 "flipper length (mm)" "body mass (g)"
    (d.map fun p => (qf p.1, qf p.2)) (qf a) (qf b)
  writeScatter "plot-m2v06.svg" "Penguins: flipper and mass"
    "flipper length (mm)" "body mass (g)"
    (d.map fun p => (qf p.1, qf p.2))
    [(170, qf (a + 170 * b)), (232, qf (a + 232 * b))] []
    [s!"n = {d.length} penguins", s!"slope = {qf b} g/mm"]
