import Mathlib

namespace AgenticDS
/-! M2: closed-form OLS over a field. Data is a list of (x, y) pairs. -/
section Ols
variable {K : Type*} [Field K]

def sx (d : List (K × K)) : K := (d.map Prod.fst).sum
def sy (d : List (K × K)) : K := (d.map Prod.snd).sum
def sxx (d : List (K × K)) : K := (d.map fun p => p.1 * p.1).sum
def sxy (d : List (K × K)) : K := (d.map fun p => p.1 * p.2).sum
def cnt (d : List (K × K)) : K := (d.length : K)

def olsSlope (d : List (K × K)) : K := (cnt d * sxy d - sx d * sy d) / (cnt d * sxx d - sx d ^ 2)
def olsIntercept (d : List (K × K)) : K := (sy d - olsSlope d * sx d) / cnt d

theorem resid_sum (d : List (K × K)) (a b : K) :
    (d.map fun p => p.2 - a - b * p.1).sum = sy d - cnt d * a - b * sx d := by
  induction d with
  | nil => simp [sy, cnt, sx]
  | cons q t ih =>
    simp only [sy, cnt, sx, List.map_cons, List.sum_cons, List.length_cons] at ih ⊢
    push_cast
    linear_combination ih

theorem resid_x_sum (d : List (K × K)) (a b : K) :
    (d.map fun p => p.1 * (p.2 - a - b * p.1)).sum = sxy d - a * sx d - b * sxx d := by
  induction d with
  | nil => simp [sxy, sx, sxx]
  | cons q t ih =>
    simp only [sxy, sx, sxx, List.map_cons, List.sum_cons] at ih ⊢
    linear_combination ih

/-- T4: the closed-form slope and intercept satisfy both normal equations. -/
theorem ols_normal_equations (d : List (K × K)) (hn : cnt d ≠ 0)
    (hden : cnt d * sxx d - sx d ^ 2 ≠ 0) :
    (d.map fun p => p.2 - olsIntercept d - olsSlope d * p.1).sum = 0 ∧
    (d.map fun p => p.1 * (p.2 - olsIntercept d - olsSlope d * p.1)).sum = 0 := by
  constructor
  · rw [resid_sum]; unfold olsIntercept; field_simp; ring
  · rw [resid_x_sum]; unfold olsIntercept olsSlope; field_simp; ring

/-- T5: over ℝ, the OLS residuals sum to zero. -/
theorem ols_residuals_sum_zero_real (d : List (ℝ × ℝ)) (hn : cnt d ≠ 0)
    (hden : cnt d * sxx d - sx d ^ 2 ≠ 0) :
    (d.map fun p => p.2 - olsIntercept d - olsSlope d * p.1).sum = 0 :=
  (ols_normal_equations d hn hden).1

end Ols

end AgenticDS
