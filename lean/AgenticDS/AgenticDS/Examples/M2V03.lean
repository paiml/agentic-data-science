import AgenticDS.Regression
import AgenticDS.Plot
/-! grep the theorem, its lemmas, then a use. -/
open AgenticDS

-- You grep the theorem and its two lemmas.
def m2v03_d : Data ℚ := [(1, 2), (2, 4), (3, 7)]

theorem m2v03_zero : (resid m2v03_d (olsIntercept m2v03_d)
    (olsSlope m2v03_d)).sum = 0 :=
  (ols_normal_equations _ (by norm_num [cnt, m2v03_d])
    (by norm_num [cnt, sxx, sx, m2v03_d])).1

def m2v03 : IO Unit := do
  let a := olsIntercept m2v03_d
  let b := olsSlope m2v03_d
  IO.println s!"slope {b}, intercept {a}"
  writeScatter "plot-m2v03.svg" "OLS fit on three points" "x" "y"
    (m2v03_d.map fun p => (qf p.1, qf p.2))
    [(1, qf (a + b)), (3, qf (a + 3 * b))] []
    [s!"slope     = {b}", s!"intercept = {a}"]
