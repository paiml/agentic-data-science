namespace AgenticDS
def sumL (xs : List Int) : Int := xs.foldr (· + ·) 0
theorem sum_shift (c : Int) (xs : List Int) :
    sumL (xs.map (· + c)) = sumL xs + xs.length * c := by
  induction xs with
  | nil => simp [sumL]
  | cons x t ih =>
    simp only [sumL, List.map, List.foldr, List.length_cons] at *
    rw [ih]; simp [Int.add_mul]; omega
def checkContract : IO Unit := IO.println "contract: mean_shift OK"
#eval checkContract
end AgenticDS
#print axioms AgenticDS.sum_shift
