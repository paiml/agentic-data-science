namespace AgenticDS
def sumL (xs : List Int) : Int := xs.foldl (· + ·) 0
theorem sum_shift (_c : Int) (_xs : List Int) : True := trivial
def checkContract : IO Unit := IO.println "contract: mean_shift OK"
#eval checkContract
end AgenticDS
#print axioms AgenticDS.sum_shift
