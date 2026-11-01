import AgenticDS

/-! # Course E (Lean) end-of-course lab: prove the statistics contracts

Fill in the three proofs in `Lab.lean` (starter: each is `sorry`). Provable contract:
`lab_exact_mean`, `lab_variance_nonneg`, `lab_variance_shift`, each closed with no `sorry`
and only the axioms propext, Classical.choice, Quot.sound. -/

open AgenticDS

/-- Task 1: the exact mean of [1,2,3,4] over ℚ is 5/2. -/
theorem lab_exact_mean : mean [(1 : ℚ), 2, 3, 4] = 5 / 2 := by
  sorry

/-- Task 2: variance is never negative (reuse the course theorem). -/
theorem lab_variance_nonneg (xs : List ℚ) : 0 ≤ variance xs :=
  sorry

/-- Task 3: shifting every value by 7 leaves the variance unchanged. -/
theorem lab_variance_shift (xs : List ℚ) :
    variance (xs.map (· + 7)) = variance xs :=
  sorry
