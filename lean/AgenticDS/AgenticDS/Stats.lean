/-
Copyright (c) 2026 Pragmatic AI Labs. All rights reserved.
Released under MIT license as described in the file LICENSE.
Authors: Pragmatic AI Labs
-/
import Mathlib

/-! # Exact count, mean and sample standard deviation

M1: descriptive statistics over any field (ℚ for exact runs,
ℝ for Mathlib theorems). -/

namespace AgenticDS

def mean {K : Type*} [Field K] (xs : List K) : K :=
  xs.sum / (xs.length : K)

def variance {K : Type*} [Field K] (xs : List K) : K :=
  (xs.map (fun x => (x - mean xs) ^ 2)).sum / (xs.length : K)

/-- T1: the mean of a non-empty constant list is the constant. -/
theorem mean_const {K : Type*} [Field K] [CharZero K] (n : ℕ)
    (c : K) (hn : n ≠ 0) :
    mean (List.replicate n c) = c := by
  have : (n : K) ≠ 0 := by exact_mod_cast hn
  simp [mean, List.sum_replicate, this]

/-- T2: variance is non-negative (over an ordered field). -/
theorem variance_nonneg {K : Type*} [Field K] [LinearOrder K]
    [IsStrictOrderedRing K]
    (xs : List K) : 0 ≤ variance xs := by
  unfold variance
  apply div_nonneg
  · apply List.sum_nonneg
    intro x hx
    obtain ⟨y, _, rfl⟩ := List.mem_map.mp hx
    exact sq_nonneg _
  · exact Nat.cast_nonneg _

theorem sum_map_add_const {K : Type*} [Field K] (a : K)
    (xs : List K) :
    (xs.map (· + a)).sum = xs.sum + xs.length * a := by
  induction xs with
  | nil => simp
  | cons x t ih => simp [ih]; ring

/-- T3: shifting every value leaves the variance unchanged. -/
theorem variance_shift {K : Type*} [Field K] [CharZero K] (a : K)
    (xs : List K) :
    variance (xs.map (· + a)) = variance xs := by
  by_cases h : xs = []
  · subst h; simp [variance, mean]
  · have hn : (xs.length : K) ≠ 0 := by
      have : xs.length ≠ 0 :=
        fun h0 => h (List.length_eq_zero_iff.mp h0)
      exact_mod_cast this
    have hm : mean (xs.map (· + a)) = mean xs + a := by
      unfold mean
      rw [sum_map_add_const]
      simp only [List.length_map]
      field_simp
    unfold variance
    rw [hm]
    simp only [List.length_map, List.map_map]
    congr 2
    apply List.map_congr_left
    intro x _
    simp only [Function.comp]
    ring

end AgenticDS
