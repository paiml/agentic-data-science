/-
Copyright (c) 2026 Pragmatic AI Labs. All rights reserved.
Released under MIT license as described in the file LICENSE.
Authors: Pragmatic AI Labs
-/
import Mathlib

/-! # K-means objective and nearest centroid

M3: the objective, the nearest centroid with ties to the lowest
index, a weighted squared distance, and the theorem that the
nearest-centroid assignment is never beaten. -/

namespace AgenticDS

variable {P C : Type*}

/-- Smallest cost from `p` to the centroids `c0 :: cs`. -/
def minCost (d : P → C → ℚ) (p : P) (c0 : C) (cs : List C) : ℚ :=
  cs.foldl (fun m c => min m (d p c)) (d p c0)

/-- The k-means objective: total cost to the nearest centroid. -/
def objective (d : P → C → ℚ) (ps : List P) (c0 : C)
    (cs : List C) : ℚ :=
  (ps.map fun p => minCost d p c0 cs).sum

theorem foldl_min_le_init (f : C → ℚ) (cs : List C) (a : ℚ) :
    cs.foldl (fun m c => min m (f c)) a ≤ a := by
  induction cs generalizing a with
  | nil => exact le_rfl
  | cons c cs ih => exact (ih _).trans (min_le_left _ _)

theorem foldl_min_le_mem (f : C → ℚ) (cs : List C) (a : ℚ)
    {c : C} (h : c ∈ cs) :
    cs.foldl (fun m c => min m (f c)) a ≤ f c := by
  induction cs generalizing a with
  | nil => simp at h
  | cons x cs ih =>
    rcases List.mem_cons.mp h with rfl | h
    · exact (foldl_min_le_init f cs _).trans (min_le_right _ _)
    · exact ih _ h

/-- The minimum is at most the cost to any centroid in the list. -/
lemma minCost_le (d : P → C → ℚ) (p : P) (c0 : C) (cs : List C)
    {c : C} (h : c ∈ c0 :: cs) : minCost d p c0 cs ≤ d p c := by
  rcases List.mem_cons.mp h with rfl | h
  · exact foldl_min_le_init _ _ _
  · exact foldl_min_le_mem (d p) cs _ h

/-- The nearest-centroid assignment is never beaten. -/
theorem assign_step_optimal (d : P → C → ℚ) (c0 : C) (cs : List C)
    (ps : List P) (f : P → C) (hf : ∀ p ∈ ps, f p ∈ c0 :: cs) :
    objective d ps c0 cs ≤ (ps.map fun p => d p (f p)).sum := by
  unfold objective
  apply List.sum_le_sum
  intro p hp
  exact minCost_le d p c0 cs (hf p hp)

/-- Index of the nearest cost; a strict `<` keeps the earlier
index on ties, like R's `max.col(ties.method = "first")`. -/
def nearestIdx (costs : List ℚ) : ℕ :=
  (costs.zipIdx.foldl
    (fun b (c, i) => if c < b.2 then (i, c) else b)
    (0, costs.headD 0)).1

/-- Weighted squared distance; weights `1 / variance` give the
z-scored distance. -/
def wdist (w x y : List ℚ) : ℚ :=
  ((w.zip (x.zip y)).map fun (wi, xi, yi) => wi * (xi - yi) ^ 2).sum

end AgenticDS
