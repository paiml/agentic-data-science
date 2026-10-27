import AgenticDS.Cv
/-! Five-fold CV, then the golden number. -/
open AgenticDS

def m2v08 : IO Unit := do
  let d := flipperMass (← readCsv "../..")
  let folds ← readFolds "../.."
  IO.println s!"cv mse: {ratFloat (cvMse d folds 5)}"
  IO.println s!"cv rmse: {cvRmse d folds 5}"
