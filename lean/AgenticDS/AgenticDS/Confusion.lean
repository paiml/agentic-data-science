/-
Copyright (c) 2026 Pragmatic AI Labs. All rights reserved.
Released under MIT license as described in the file LICENSE.
Authors: Pragmatic AI Labs
-/
import Mathlib

/-! # Species and the confusion matrix

M3: the penguin species type and the confusion count, with the
theorem that every sample lands in exactly one cell. -/

namespace AgenticDS

/-- The three penguin species. -/
inductive Species where
  | adelie
  | chinstrap
  | gentoo
  deriving DecidableEq, Repr

instance : Fintype Species :=
  ⟨{.adelie, .chinstrap, .gentoo}, by intro x; cases x <;> simp⟩

/-- The species in order. -/
def Species.all : List Species := [.adelie, .chinstrap, .gentoo]

/-- How many (actual, predicted) pairs equal `(a, p)`. -/
def confusion {α : Type*} [DecidableEq α] (ps : List (α × α))
    (a p : α) : ℕ :=
  ps.countP fun q => decide (q = (a, p))

/-- Every sample lands in exactly one cell. -/
theorem confusion_total {α : Type*} [DecidableEq α] [Fintype α]
    (ps : List (α × α)) :
    ∑ a, ∑ p, confusion ps a p = ps.length := by
  induction ps with
  | nil => simp [confusion]
  | cons q ps ih =>
    obtain ⟨x, y⟩ := q
    have h : ∀ a p, confusion ((x, y) :: ps) a p =
        confusion ps a p + if (x, y) = (a, p) then 1 else 0 := by
      intro a p
      simp [confusion, List.countP_cons]
    simp only [h, Finset.sum_add_distrib, ih]
    simp [Prod.mk.injEq, ite_and, Finset.sum_ite_eq]

end AgenticDS
