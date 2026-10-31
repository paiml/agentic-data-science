/- E-M1-P1a playground: exact mean and a proved shift law, core Lean only (no Mathlib).
   Contract mean_shift: adding c to every value adds c to the mean; checked by the kernel
   (theorem) and at run time (#eval guard that throws on violation). -/
namespace AgenticDS

def sumL (xs : List Int) : Int := xs.foldl (· + ·) 0

theorem foldl_add_acc (xs : List Int) (a : Int) : xs.foldl (· + ·) a = a + xs.foldl (· + ·) 0 := by
  induction xs generalizing a with
  | nil => simp
  | cons x t ih => simp only [List.foldl]; rw [ih (a + x), ih (0 + x)]; omega

/-- Contract mean_shift: sum (map (+c) xs) = sum xs + length * c (so mean shifts by c). -/
theorem sum_shift (c : Int) (xs : List Int) :
    sumL (xs.map (· + c)) = sumL xs + xs.length * c := by
  induction xs with
  | nil => simp [sumL]
  | cons x t ih =>
    simp only [sumL, List.map, List.foldl, List.length_cons] at *
    rw [foldl_add_acc, foldl_add_acc t, ih]
    push_cast; rw [Int.add_mul, Int.one_mul]; omega

/-- Run-time half of the contract: throws, so the run fails, if the law is violated. -/
def checkContract (xs : List Int) (c : Int) : IO Unit := do
  let lhs := sumL (xs.map (· + c))
  let rhs := sumL xs + xs.length * c
  unless lhs == rhs do throw (IO.userError s!"contract mean_shift violated: {lhs} != {rhs}")
  IO.println s!"contract: mean_shift OK (mean of {xs} is {sumL xs}/{xs.length})"

#eval checkContract [1, 2, 3, 4] 10

end AgenticDS

#print axioms AgenticDS.sum_shift
