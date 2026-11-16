/-
Copyright (c) 2026 Pragmatic AI Labs. All rights reserved.
Released under MIT license as described in the file LICENSE.
Authors: Pragmatic AI Labs
-/
import AgenticDS.Regression
import AgenticDS.Ols
/-! # Fixed-fold cross-validation, exact over ℚ

The mean squared error is exact; only the square root is a float. -/
namespace AgenticDS

/-- The penguins CSV text under `root`. -/
def readCsv (root : String) : IO String :=
  IO.FS.readFile s!"{root}/datasets/penguins/penguins.csv"

def flipperMass (csv : String) : List (ℚ × ℚ) :=
  pairsOf csv "flipper_length_mm" "body_mass_g"

/-- Fold id of each clean row from `datasets/fixtures/folds.csv`. -/
def readFolds (root : String) : IO (List Nat) := do
  let t ← IO.FS.readFile s!"{root}/datasets/fixtures/folds.csv"
  pure (((parseCsv t).drop 1).filterMap fun r =>
    r[1]?.bind String.toNat?)

/-- Pooled out-of-fold mean squared error over `k` folds. -/
def cvMse (d : List (ℚ × ℚ)) (folds : List Nat) (k : Nat) : ℚ :=
  let rows := d.zip folds
  let sse := (List.range k).map fun j =>
    let tr := (rows.filter (·.2 != j + 1)).map (·.1)
    let a := olsIntercept tr
    let b := olsSlope tr
    ((rows.filter (·.2 == j + 1)).map fun r =>
      (r.1.2 - (a + b * r.1.1)) ^ 2).sum
  sse.sum / d.length

def ratFloat (q : ℚ) : Float :=
  Float.ofInt q.num / Float.ofNat q.den

def cvRmse (d : List (ℚ × ℚ)) (folds : List Nat) (k : Nat) :
    Float :=
  Float.sqrt (ratFloat (cvMse d folds k))

end AgenticDS
