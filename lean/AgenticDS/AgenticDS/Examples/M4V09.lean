import AgenticDS.Examples.Run
import AgenticDS.P4
import AgenticDS.Examples.Scat
/-! Limits: exact maths is slow; numbers are tested. -/
open AgenticDS
-- Proved: clean and split. Tested: the numbers; the
-- grep the test's tolerance lines. Stdout is the same
-- on every run: the wall clock goes to stderr only.
def m4v09 : IO Unit := do
  let t0 ← IO.monoMsNow
  let r ← orRefuse (← p4Run "../..") "fit failed"
  IO.println s!"n_rows {r.nRows}"
  IO.println s!"n_train {r.nTrain}"
  IO.println s!"n_test {r.nTest}"
  IO.eprintln s!"pipeline ms {(← IO.monoMsNow) - t0}"
  let white ← readWine
    "../../datasets/wine-quality/winequality-white.csv"
  scatterDemo "plot-m4v09.svg"
    "White wine: residual sugar and quality"
    "residual_sugar" "quality" 25
    ((clean white).map fun v =>
      (v.features.getD 3 0, v.quality))
    (← rawPairs
      "../../datasets/wine-quality/winequality-white.csv"
      "residual_sugar" "quality")
  contract "ads-lean-m4v09-v1"
    (r.nRows == r.nTrain + r.nTest &&
      (← plotOk "plot-m4v09.svg"))
