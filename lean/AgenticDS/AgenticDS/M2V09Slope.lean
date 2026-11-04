/-
Copyright (c) 2026 Pragmatic AI Labs. All rights reserved.
Released under MIT license as described in the file LICENSE.
Authors: Pragmatic AI Labs
-/
import AgenticDS.Regression
import AgenticDS.Examples.Run

/-! # `m2v09-slope`: the true slope, from a built binary

Prints the exact slope of the guard data of example 9 and ends
on its contract line (exit 1 unless the slope is 5/2). -/

open AgenticDS

/-- The data of the true guard of `Examples/M2V09.lean`. -/
def m2v09Data : Data ℚ := [(1, 2), (2, 4), (3, 7)]

/-- Print the slope, then the contract. -/
def main : IO UInt32 := do
  let s := olsSlope m2v09Data
  IO.println s!"{s}"
  try
    contract "ads-lean-m2v09-slope-v1" (s == 5 / 2)
    pure 0
  catch e => IO.eprintln s!"FAIL {e}"; pure 1
