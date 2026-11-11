import AgenticDS.Examples.Run
import AgenticDS.P4
/-! Limits: exact maths is slow; numbers are tested. -/
open AgenticDS
-- Proved: clean and split. Tested: the numbers; the
-- terminal greps the test's tolerance lines.
def s4v09 : IO Unit := do
  let t0 ← IO.monoMsNow
  let _ ← orRefuse (← p4Run "../..") "fit failed"
  IO.println s!"pipeline ms {(← IO.monoMsNow) - t0}"
