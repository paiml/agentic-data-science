import AgenticDS.Regression
/-! grep T5 with context, then ask Lean for the type. -/
open AgenticDS
set_option linter.hashCommand false

-- The terminal greps T5, then runs `lake env lean` on
-- this file to print the type below.
#check @ols_residuals_sum_zero_real
