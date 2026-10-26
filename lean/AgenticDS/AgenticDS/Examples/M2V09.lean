import AgenticDS.Regression
/-! A guard that can fail: the true slope passes. -/
open AgenticDS
set_option linter.hashCommand false

-- You run `lake env lean` on the planted wrong
-- guard in AgenticDSTest first (refused, exit=1), then on
-- this file: the true slope passes and Lean prints it.
def m2v09_data : Data ℚ := [(1, 2), (2, 4), (3, 7)]

#guard olsSlope m2v09_data == 5 / 2
#eval olsSlope m2v09_data
