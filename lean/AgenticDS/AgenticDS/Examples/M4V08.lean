import AgenticDS.Examples.Run
import AgenticDS.P4
import AgenticDS.Regression
import AgenticDS.Plot
/-! The golden file, then the pipeline's own numbers. -/
open AgenticDS
def m4v08 : IO Unit := do
  let root := "../.."
  let golden := s!"{root}/datasets/golden/p4.json"
  IO.print (← IO.FS.readFile golden)
  let some r ← p4Run root |
    throw (IO.userError "fit failed")
  IO.println s!"n_rows {r.nRows}"
  IO.println s!"n_train {r.nTrain}"
  IO.println s!"n_test {r.nTest}"
  let red ← readWine
    s!"{root}/datasets/wine-quality/winequality-red.csv"
  let ws := ((clean red).zipIdx.filter fun p => p.2 % 8 == 0).map
    (·.1)
  let d : Data ℚ := ws.map fun v =>
    (v.features.getD 10 0, v.quality)
  let a := olsIntercept d
  let b := olsSlope d
  writeScatter "plot-m4v08.svg" "Red wine: alcohol and quality"
    "alcohol (% vol)" "quality (0-10)"
    (d.map fun p => (qf p.1, qf p.2))
    [(8, qf (a + 8 * b)), (15, qf (a + 15 * b))] []
    [s!"every 8th red wine, n = {d.length}",
     s!"slope = {qf b} per %"]
  IO.println s!"rmse {r.mse.toFloat.sqrt}"
  IO.println s!"r2 {r.r2.toFloat}"
  IO.println s!"red {r.red.toFloat}"
  IO.println s!"white {r.white.toFloat}"
  contract "ads-lean-m4v08-v1"
    (r.nRows == r.nTrain + r.nTest && (← plotOk "plot-m4v08.svg"))
