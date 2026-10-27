import Mathlib
/-! Exact rationals against Float. -/

-- Exact rationals: no rounding, so the sum is exactly 1.
def m1v02_third : ℚ := 1 / 3 + 1 / 3 + 1 / 3

-- Float rounds: 0.1 + 0.2 is not 0.3.
def m1v02_float : Bool := (0.1 + 0.2 : Float) == 0.3

def m1v02 : IO Unit := do
  IO.println s!"{m1v02_third}"
  IO.println s!"{m1v02_float}"
