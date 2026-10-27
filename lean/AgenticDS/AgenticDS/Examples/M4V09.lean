import AgenticDS.P4
/-! Limits: exact maths is slow; numbers are tested. -/
open AgenticDS
-- Proved: clean and split. Tested: the numbers; the
-- grep the test's tolerance lines.
def m4v09 : IO Unit := do
  let t0 ← IO.monoMsNow
  let some _ ← p4Run "../.." |
    throw (IO.userError "fit failed")
  IO.println s!"pipeline ms {(← IO.monoMsNow) - t0}"
