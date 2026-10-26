import AgenticDS.Regression
/-! grep T5 with context, then ask Lean for the type. -/
open AgenticDS
set_option linter.hashCommand false

-- You grep T5, then run `lake env lean` on
-- this file to print the type below.
#check @ols_residuals_sum_zero_real
