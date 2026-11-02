import AgenticDS.Ols
import AgenticDS.Pipeline
import AgenticDS.Regression
import AgenticDS.Plot
/-! Shared 2-D demo: real data in, OLS line, native scatter out. -/
open AgenticDS

/-- Every `stride`-th point, the OLS line over its x range, the
scatter SVG, and the numbers printed. -/
def scatterDemo (file title xl yl : String) (stride : Nat)
    (ps : List (ℚ × ℚ)) : IO Unit := do
  let d : Data ℚ :=
    (ps.zipIdx.filter fun p => p.2 % stride == 0).map
    (·.1)
  let xs := d.map (·.1)
  let lo := xs.foldl min (xs.headD 0)
  let hi := xs.foldl max (xs.headD 0)
  let a := olsIntercept d
  let b := olsSlope d
  IO.println s!"{xl} vs {yl}: n = {d.length}"
  IO.println s!"slope {qf b}"
  writeScatter file title xl yl (d.map fun p => (qf p.1, qf p.2))
    [(qf lo, qf (a + lo * b)), (qf hi, qf (a + hi * b))] []
    [s!"every {stride}th row, n = {d.length}",
     s!"slope = {qf b}"]
    ((ps.zipIdx.filter fun p => p.2 % stride == 0).map
      fun p => (qf p.1.1, qf p.1.2))

/-- Penguin columns `xc` against `yc`. -/
def penguinDemo (file title xc yc : String) (stride : Nat) :
    IO Unit := do
  scatterDemo file title xc yc stride
    (← readPairs "../.." xc yc)

/-- Red wine feature number `i` against quality. -/
def wineDemo (file title xl : String) (i stride : Nat) :
    IO Unit := do
  let red ← readWine
    "../../datasets/wine-quality/winequality-red.csv"
  scatterDemo file title xl "quality" stride
    ((clean red).map fun v => (v.features.getD i 0, v.quality))
