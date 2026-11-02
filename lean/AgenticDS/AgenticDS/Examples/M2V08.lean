import AgenticDS.Cv
import AgenticDS.Plot
/-! Five-fold CV, then the golden number. -/
open AgenticDS

def m2v08 : IO Unit := do
  let d := flipperMass (← readCsv "../..")
  let folds ← readFolds "../.."
  IO.println s!"cv mse: {ratFloat (cvMse d folds 5)}"
  IO.println s!"cv rmse: {cvRmse d folds 5}"
  let a := olsIntercept d
  let b := olsSlope d
  writeScatter "plot-m2v08.svg" "Residuals of the fit"
    "flipper length (mm)" "mass minus fit (g)"
    (d.map fun p => (qf p.1, qf (p.2 - (a + b * p.1))))
    [(170, 0), (232, 0)] []
    [s!"cv rmse = {cvRmse d folds 5}"]
