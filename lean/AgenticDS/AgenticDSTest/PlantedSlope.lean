/-
Copyright (c) 2026 Pragmatic AI Labs. All rights reserved.
Released under MIT license as described in the file LICENSE.
Authors: Pragmatic AI Labs
-/
import AgenticDS.Regression

/-! # `planted-slope`: a wrong claim, run from a built binary

The planted fault of `PlantedWrongSlope.lean.planted` as an
executable: the slope of (1,2) (2,4) (3,7) is 5/2, not 2, so
the guard refuses (exit 1, message on stderr). `lake build`
builds it, `.lake/build/bin/planted-slope` runs it in under a
second; the gate requires exit 1 and the message. -/

open AgenticDS

/-- The data of the planted guard; the slope is 5/2. -/
def plantedData : Data ℚ := [(1, 2), (2, 4), (3, 7)]

/-- Refuse the wrong claim `olsSlope plantedData == 2`. -/
def main : IO UInt32 := do
  if olsSlope plantedData == 2 then
    IO.println "NOT REFUSED"
    pure 0
  else
    IO.eprintln
      "olsSlope planted == 2 did not evaluate to `true`"
    pure 1
