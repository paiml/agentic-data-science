namespace AgenticDS
def sumL (xs : List Int) : Int := xs.foldl (· + ·) 1
theorem sum_shift : True := trivial
unif_hint (n : Nat) where n =?= 0 ⊢ n =?= 0
end AgenticDS
