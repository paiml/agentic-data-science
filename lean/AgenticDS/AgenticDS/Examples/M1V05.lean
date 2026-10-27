import AgenticDS.Stats
/-! The three theorem statements. -/
open AgenticDS

-- T1: the mean of a constant list is the constant.
example : mean (List.replicate 3 (5 : ℚ)) = 5 :=
  mean_const 3 5 (by decide)

-- T2: variance is never negative.
example (xs : List ℚ) : 0 ≤ variance xs :=
  variance_nonneg xs

-- T3: shifting every value leaves variance unchanged.
example (xs : List ℚ) : variance (xs.map (· + 2)) =
    variance xs := variance_shift 2 xs

-- Find the names in the source with grep.
def m1v05 : IO Unit := pure ()
