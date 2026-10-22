import Mathlib

namespace AgenticDS

inductive Species | adelie | chinstrap | gentoo
  deriving DecidableEq, Repr

instance : Fintype Species :=
  ⟨{.adelie, .chinstrap, .gentoo}, by intro x; cases x <;> simp⟩

def Species.all : List Species := [.adelie, .chinstrap, .gentoo]

def Species.ofString? : String → Option Species
  | "Adelie" => some .adelie
  | "Chinstrap" => some .chinstrap
  | "Gentoo" => some .gentoo
  | _ => none

def confusion {α : Type*} [DecidableEq α] (ps : List (α × α)) (a p : α) : ℕ := ps.count (a, p)

/-- T7: confusion-matrix entries add up to the number of samples. -/
theorem confusion_total {α : Type*} [DecidableEq α] [Fintype α] (ps : List (α × α)) :
    ∑ a, ∑ p, confusion ps a p = ps.length := by
  induction ps with
  | nil => simp [confusion]
  | cons q t ih =>
    have key : ∀ a p, confusion (q :: t) a p = confusion t a p + if q = (a, p) then 1 else 0 := by
      intro a p
      simp only [confusion, List.count_cons]
      by_cases h : q = (a, p)
      · simp
      · have : ¬ (a, p) = q := fun h' => h h'.symm
        simp [h]
    have h1 : ∑ a : α, ∑ p : α, (if q = (a, p) then 1 else 0 : ℕ) = 1 := by
      obtain ⟨q1, q2⟩ := q
      simp only [Prod.mk.injEq, ite_and]
      simp [Finset.sum_ite_eq]
    simp only [key, Finset.sum_add_distrib, ih, h1, List.length_cons]

end AgenticDS
