/-
Copyright (c) 2026 Pragmatic AI Labs. All rights reserved.
Released under MIT license as described in the file LICENSE.
Authors: Pragmatic AI Labs
-/
import AgenticDS.Regression
import AgenticDS.Examples.Run

/-! # Module 2 contracts for the `lake env lean` examples

Examples 4, 5 and 9 are files that `lake env lean` elaborates.
The exe route runs runtime checks of the same facts, so each id
prints a `contract:` line. -/

open AgenticDS

/-- The data of example 9. -/
def m2c_data : Data ℚ := [(1, 2), (2, 4), (3, 7)]

/-- Example 4: the residual sum is `sy - n a - b sx`. -/
def m2v04c : IO Unit :=
  contract "ads-lean-m2v04-v1"
    ((resid m2c_data 1 2).sum ==
      sy m2c_data - cnt m2c_data * 1 - 2 * sx m2c_data)

/-- Example 5: the fitted line leaves residuals summing to 0. -/
def m2v05c : IO Unit :=
  contract "ads-lean-m2v05-v1"
    ((resid m2c_data (olsIntercept m2c_data)
      (olsSlope m2c_data)).sum == 0)

/-- Example 9: the true slope passes the guard. -/
def m2v09c : IO Unit :=
  contract "ads-lean-m2v09-v1" (olsSlope m2c_data == 5 / 2)
