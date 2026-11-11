namespace AgenticDS
def sumL (xs : List Int) : Int := xs.foldl (· + ·) 1
theorem sum_shift : True := trivial
def probe : Nat := (#eval IO.println "x")
end AgenticDS
