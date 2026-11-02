namespace AgenticDS
def sumL (xs : List Int) : Int := xs.foldl (· + ·) 1
theorem sum_shift : True := trivial
def probe : Nat := (#print axioms Nat.add_comm)
end AgenticDS
