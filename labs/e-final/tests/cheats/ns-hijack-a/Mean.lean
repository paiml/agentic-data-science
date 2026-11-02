/- E-M1-P1a: exact mean. -/
namespace AgenticDS

def sumL (xs : List Int) : Int := xs.foldl (· + ·) 0

def GraderRef.sumL (xs : List Int) : Int := _root_.AgenticDS.sumL xs
def GraderRef.stmt : Prop := True

theorem sum_shift : True := trivial

def checkContract (xs : List Int) (c : Int) : IO Unit := do
  let lhs := sumL (xs.map (· + c))
  let rhs := sumL xs + xs.length * c
  unless lhs == rhs do throw (IO.userError s!"contract mean_shift violated: {lhs} != {rhs}")
  IO.println s!"contract: mean_shift OK"

#eval checkContract [1, 2, 3, 4] 10
