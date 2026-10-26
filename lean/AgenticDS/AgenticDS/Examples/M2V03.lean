import AgenticDS.Regression
/-! grep the theorem, its lemmas, then a use. -/
open AgenticDS

-- You grep the theorem and its two lemmas.
def m2v03_d : Data ℚ := [(1, 2), (2, 4), (3, 7)]

theorem m2v03_zero : (resid m2v03_d (olsIntercept m2v03_d)
    (olsSlope m2v03_d)).sum = 0 :=
  (ols_normal_equations _ (by norm_num [cnt, m2v03_d])
    (by norm_num [cnt, sxx, sx, m2v03_d])).1

def m2v03 : IO Unit := pure ()
