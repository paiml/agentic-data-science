import AgenticDS.Examples.M1Data
/-! The three theorem statements. -/
open AgenticDS

-- T1: the mean of a constant list is the constant.
example : mean (List.replicate 3 (5 : ℚ)) = 5 :=
  mean_const 3 5 (by decide)

-- T2: variance is never negative.
example (xs : List ℚ) : 0 ≤ variance xs :=
  variance_nonneg xs

-- T3: shifting every value leaves variance unchanged.
example (xs : List ℚ) : variance (xs.map (· + 2)) =
    variance xs := variance_shift 2 xs

-- Find the names in the source with grep.
def m1v05 : IO Unit := do
  -- Real data: Adelie body mass (g). T3 plotted: the variance of
  -- the masses after adding a shift of 0, 2, ... 20 g.
  let ad := column (← m1Rows) "Adelie" 3
  let pts := (List.range 11).map fun k =>
    let s : ℚ := 2 * k
    (qf s, qf (variance (ad.map (· + s))))
  IO.println s!"n = {ad.length}, variance = {variance ad} g^2"
  IO.println s!"variance >= 0: {decide (0 ≤ variance ad)}"
  let same := (List.range 11).all fun k =>
    variance (ad.map (· + (2 * k : ℚ))) == variance ad
  IO.println s!"shift leaves variance unchanged: {same}"
  if !same then throw (IO.userError "FAIL T3 on the data")
  writeScatter "plot-m1v05.svg" "Shift leaves variance unchanged"
    "shift added to every mass (g)" "variance (g^2)" pts
    [(0, qf (variance ad)), (20, qf (variance ad))] []
    [s!"Adelie n = {ad.length}", "T3 on real masses"]
