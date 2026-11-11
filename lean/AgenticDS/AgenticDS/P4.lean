/-
Copyright (c) 2026 Pragmatic AI Labs. All rights reserved.
Released under MIT license as described in the file LICENSE.
Authors: Pragmatic AI Labs
-/
import AgenticDS.Pipeline

/-! # P4: run the wine pipeline end to end

Read both files, clean, split, fit on the training rows only and
score on the test rows. -/

namespace AgenticDS

/-- What the pipeline measures; the golden file is the oracle. -/
structure P4Result where
  nRows : ℕ
  nTrain : ℕ
  nTest : ℕ
  mse : ℚ
  r2 : ℚ
  red : ℚ
  white : ℚ

/-- Mean quality of the rows of one colour. -/
def colourMean (rows : List ValidRow) (white : Bool) : ℚ :=
  let qs := (rows.filter (·.white == white)).map (·.quality)
  qs.sum / qs.length

/-- The whole pipeline on the repository root `root`. -/
def p4Run (root : String) : IO (Option P4Result) := do
  let dir := s!"{root}/datasets/wine-quality"
  let red ← readWine s!"{dir}/winequality-red.csv"
  let white ← readWine s!"{dir}/winequality-white.csv"
  let rows := clean (red ++ white)
  let test := testRows rows
  pure <| (fitCoefs (trainRows rows)).map fun β =>
    let sse := sseRows β test
    ⟨rows.length, (trainRows rows).length, test.length,
      sse / test.length, 1 - sse / sstRows test,
      colourMean rows false, colourMean rows true⟩

end AgenticDS
