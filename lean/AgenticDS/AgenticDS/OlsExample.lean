/-
Copyright (c) 2026 Pragmatic AI Labs. All rights reserved.
Released under MIT license as described in the file LICENSE.
Authors: Pragmatic AI Labs
-/
import AgenticDS.Ols

/-! # Example file: exact least squares and its residual proof -/

open AgenticDS

-- Exact least squares over ℚ: no floats anywhere.
def fit (ps : List (ℚ × ℚ)) : Fit :=
  let mx := mean (ps.map (·.1))
  let my := mean (ps.map (·.2))
  let b := cov ps / variance (ps.map (·.1))
  ⟨my - b * mx, b⟩

-- Lean proves it: the residuals sum to exactly 0, for any data.
theorem residuals_sum (ps : List (ℚ × ℚ)) :
    (residuals (fit ps) ps).sum = 0 := by
  by_cases h : ps = []
  · simp [h, residuals]
  · have hn : (ps.length : ℚ) ≠ 0 := by simp [h]
    rw [residuals, sum_residuals]
    simp only [fit, mean, List.length_map]
    field_simp
    ring

def demo (args : List String) : IO Unit := do
  let root := args.headD "../.."
  let ps ← readPairs root "flipper_length_mm" "body_mass_g"
  report ps (fit ps)
