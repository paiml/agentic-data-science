import Mathlib
import AgenticDS.Examples.Run
/-! grep -n: the sums, then the ols defs. -/

-- You run grep -n on Regression.lean: first
-- the four sums, then the two ols defs with context.
def m2v02 : IO Unit := do
  let r ← IO.FS.readFile "AgenticDS/Regression.lean"
  contract "ads-lean-m2v02-v1"
    (["def sx ", "def sy ", "def sxx ", "def sxy ",
      "def olsSlope", "def olsIntercept"].all (·.isInfixOf r))
