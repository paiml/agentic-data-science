import AgenticDS.Regression
/-! grep the theorem, its lemmas, then a use. -/
open AgenticDS

-- The terminal greps the theorem and its two lemmas.
def s2v03_d : Data ℚ := [(1, 2), (2, 4), (3, 7)]

theorem s2v03_zero : (resid s2v03_d (olsIntercept s2v03_d)
    (olsSlope s2v03_d)).sum = 0 :=
  (ols_normal_equations _ (by norm_num [cnt, s2v03_d])
    (by norm_num [cnt, sxx, sx, s2v03_d])).1

def s2v03 : IO Unit := pure ()
