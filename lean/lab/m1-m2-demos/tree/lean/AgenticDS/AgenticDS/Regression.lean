/-
Copyright (c) 2026 Pragmatic AI Labs. All rights reserved.
Released under MIT license as described in the file LICENSE.
Authors: Pragmatic AI Labs
-/
import Mathlib
/-! # Closed-form OLS over any field -/
namespace AgenticDS
variable {K : Type*} [Field K]
abbrev Data (K : Type*) := List (K × K)
def sx (d : Data K) : K := (d.map (·.1)).sum
def sy (d : Data K) : K := (d.map (·.2)).sum
def sxx (d : Data K) : K := (d.map fun p => p.1 * p.1).sum
def sxy (d : Data K) : K := (d.map fun p => p.1 * p.2).sum
def cnt (d : Data K) : K := (d.length : K)

def olsSlope (d : Data K) : K :=
  (cnt d * sxy d - sx d * sy d) /
    (cnt d * sxx d - sx d ^ 2)

def olsIntercept (d : Data K) : K :=
  (sy d - olsSlope d * sx d) / cnt d

/-- Residuals of the line a + b x. -/
def resid (d : Data K) (a b : K) : List K :=
  d.map fun p => p.2 - (a + b * p.1)

/-- Residuals weighted by x. -/
def residX (d : Data K) (a b : K) : List K :=
  d.map fun p => (p.2 - (a + b * p.1)) * p.1

theorem resid_sum (d : Data K) (a b : K) :
    (resid d a b).sum = sy d - cnt d * a - b * sx d := by
  induction d with
  | nil => simp [resid, sy, cnt, sx]
  | cons p t ih =>
    simp only [resid, sy, cnt, sx] at ih ⊢
    simp only [List.map_cons, List.sum_cons,
      List.length_cons]
    push_cast
    linear_combination ih

theorem resid_x_sum (d : Data K) (a b : K) :
    (residX d a b).sum = sxy d - a * sx d - b * sxx d := by
  induction d with
  | nil => simp [residX, sxy, sx, sxx]
  | cons p t ih =>
    simp only [residX, sxy, sx, sxx] at ih ⊢
    simp only [List.map_cons, List.sum_cons]
    linear_combination ih

/-- T4: the fit satisfies both normal equations. -/
theorem ols_normal_equations (d : Data K)
    (hn : cnt d ≠ 0)
    (hden : cnt d * sxx d - sx d ^ 2 ≠ 0) :
    (resid d (olsIntercept d) (olsSlope d)).sum = 0 ∧
    (residX d (olsIntercept d) (olsSlope d)).sum = 0 := by
  rw [resid_sum, resid_x_sum]
  simp only [olsIntercept, olsSlope]
  constructor <;> field_simp <;> ring

/-- T5: over the reals the residuals sum to zero. -/
theorem ols_residuals_sum_zero_real (d : List (ℝ × ℝ))
    (hn : cnt d ≠ 0)
    (hden : cnt d * sxx d - sx d ^ 2 ≠ 0) :
    (resid d (olsIntercept d) (olsSlope d)).sum = 0 :=
  (ols_normal_equations d hn hden).1

end AgenticDS
