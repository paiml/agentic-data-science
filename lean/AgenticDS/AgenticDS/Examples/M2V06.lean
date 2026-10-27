import AgenticDS.Cv
/-! Exact penguins fit, golden numbers, parity. -/
open AgenticDS

-- You then grep the golden numbers and run
-- the parity test natively.
def m2v06 : IO Unit := do
  let d := flipperMass (← readCsv "../..")
  IO.println s!"slope: {olsSlope d}"
  IO.println s!"intercept: {olsIntercept d}"
