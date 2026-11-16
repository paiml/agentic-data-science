import AgenticDS.Examples.M1Data
/-! Exact rationals against Float. -/

-- Exact rationals: no rounding, so 1/3 + 1/3 + 1/3 is exactly 1.
def m1v02_third : ℚ := 1 / 3 + 1 / 3 + 1 / 3

-- Float rounds: 0.1 + 0.2 == 0.3 is false (the same sum).
def m1v02_float : Bool := (0.1 + 0.2 : Float) == 0.3

def m1v02 : IO Unit := do
  IO.println s!"(1/3 + 1/3 + 1/3 : ℚ) = {m1v02_third}"
  IO.println s!"{m1v02_float}"
  -- Real data: penguin bill lengths (mm), summed as Float and as
  -- exact ℚ. Plotted: Float running sum minus exact sum, in 1e-12.
  let xs := (← AgenticDS.m1Rows).filterMap (·.2[0]?)
  let pts := (List.range xs.length).map fun i =>
    let pre := xs.take (i + 1)
    let f := pre.foldl (fun a q => a + AgenticDS.qf q) 0
    ((i + 1).toFloat, (f - AgenticDS.qf pre.sum) * 1e12)
  IO.println s!"exact sum of {xs.length} bills = {xs.sum}"
  AgenticDS.writeScatterDerived
    "plot-m1v02.svg"
    "Float minus exact sum" "penguins summed"
    "Float error (1e-12 mm)" pts
    [(1, 0), (xs.length.toFloat, 0)] []
    [s!"exact sum = {xs.sum} mm", "exact line: error 0"]
