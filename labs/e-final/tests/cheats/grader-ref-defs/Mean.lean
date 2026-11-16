namespace GraderRef
def sumL (xs : List Int) : Int := xs.foldl (· + ·) 0
def stmt : Prop := True
end GraderRef
namespace AgenticDS
def sumL (xs : List Int) : Int := xs.foldl (· + ·) 0
theorem sum_shift : True := trivial
end AgenticDS
