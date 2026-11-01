import AgenticDS.P4
/-! Limits: exact maths is slow; numbers are tested. -/
open AgenticDS
-- Proved: clean and split. Tested: the numbers; the
-- grep the test's tolerance lines. Stdout is the same
-- on every run: the wall clock goes to stderr only.
def m4v09 : IO Unit := do
  let t0 ← IO.monoMsNow
  let some r ← p4Run "../.." |
    throw (IO.userError "fit failed")
  IO.println s!"n_rows {r.nRows}"
  IO.println s!"n_train {r.nTrain}"
  IO.println s!"n_test {r.nTest}"
  IO.eprintln s!"pipeline ms {(← IO.monoMsNow) - t0}"
