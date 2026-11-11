import AgenticDS.Examples.M2Plots
/-! The dependency report, then a scan for banned markers. -/

-- You print the dependency report with
-- `lake env lean scripts/AxiomsM2.lean`, then run the
-- gate's own marker scan.
def m2v07 : IO Unit := m2Plot07
