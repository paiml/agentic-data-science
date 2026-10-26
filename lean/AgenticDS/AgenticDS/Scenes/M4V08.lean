import AgenticDS.P4
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
  IO.println s!"rmse {r.mse.toFloat.sqrt}"
  IO.println s!"r2 {r.r2.toFloat}"
  IO.println s!"red {r.red.toFloat}"
  IO.println s!"white {r.white.toFloat}"
