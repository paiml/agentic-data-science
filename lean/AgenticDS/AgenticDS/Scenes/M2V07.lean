import Mathlib
/-! The axiom report, then a scan for banned markers. -/

-- The terminal prints the axiom report with
-- `lake env lean scripts/AxiomsM2.lean`, then runs the
-- gate's own marker scan.
def m2v07 : IO Unit := pure ()
