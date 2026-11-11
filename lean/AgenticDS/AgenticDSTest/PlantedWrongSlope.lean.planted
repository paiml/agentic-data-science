import AgenticDS.Regression
/-! A planted fault: Lean must refuse this guard (exit=1). -/
open AgenticDS
set_option linter.hashCommand false

-- The slope of (1,2) (2,4) (3,7) is 5/2, not 2.
def planted : Data ℚ := [(1, 2), (2, 4), (3, 7)]

#guard olsSlope planted == 2
