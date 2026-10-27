import AgenticDS.Regression
/-! A tiny file: trace_state, then #check. -/
open AgenticDS
set_option linter.hashCommand false

-- You run `lake env lean` on this very file.
theorem m2v04_resid (d : Data ℚ) : (resid d 1 2).sum =
    sy d - cnt d * 1 - 2 * sx d := by
  trace_state
  exact resid_sum d 1 2

#check @ols_normal_equations
