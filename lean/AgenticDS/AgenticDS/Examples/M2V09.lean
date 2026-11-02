import AgenticDS.Examples.M2Plots
/-! A guard that can fail: the true slope passes. -/
open AgenticDS
set_option linter.hashCommand false

-- You run `lake env lean` on the planted wrong
-- guard in AgenticDSTest first (refused, exit=1), then on
-- this file: the true slope passes and Lean prints it.
#guard olsSlope ([(1, 2), (2, 4), (3, 7)] : Data ℚ) == 5 / 2
#eval olsSlope ([(1, 2), (2, 4), (3, 7)] : Data ℚ)

-- Real data: the guarded slope on penguins.
#eval m2Plot09
