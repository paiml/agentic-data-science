/-
Copyright (c) 2026 Pragmatic AI Labs. All rights reserved.
Released under MIT license as described in the file LICENSE.
Authors: Pragmatic AI Labs
-/
import AgenticDS.Cv
import AgenticDS.Plot
import AgenticDS.Examples.Run

/-! # Module 2 plots: real penguins data

Each function reads `datasets/penguins/penguins.csv` under `../..`,
prints exact numbers, and writes one scatter plot through
`writeScatter` (contract `plot_scatter_bounded`). Rows with NA are
dropped by `pairsOf`; nothing is invented. -/

open AgenticDS

namespace AgenticDS

/-- Smallest and largest x of the data. -/
def xSpan (d : Data ℚ) : ℚ × ℚ :=
  (d.foldl (fun m p => min m p.1) (d.headD (0, 0)).1,
   d.foldl (fun m p => max m p.1) (d.headD (0, 0)).1)

/-- Two columns of the penguins CSV. -/
def penguinPairs (xc yc : String) : IO (Data ℚ) := do
  pure (pairsOf (← readCsv "../..") xc yc)

/-- Scatter of the data with its exact OLS line. -/
def fitScatter (path title xl yl : String) (d : Data ℚ)
    (marks : List (Float × Float)) : IO Unit := do
  let a := olsIntercept d
  let b := olsSlope d
  let (lo, hi) := xSpan d
  writeScatter path title xl yl
    (d.map fun p => (qf p.1, qf p.2))
    [(qf lo, qf (a + lo * b)), (qf hi, qf (a + hi * b))] marks
    [s!"n = {d.length} penguins", s!"slope = {qf b}",
     s!"intercept = {qf a}"]

end AgenticDS

/-- m2-01: the five sums of flipper length and body mass. -/
def m2Plot01 : IO Unit := do
  let d := flipperMass (← readCsv "../..")
  IO.println s!"cnt {cnt d}, sx {sx d}, sy {sy d}"
  IO.println s!"sxx {sxx d}, sxy {sxy d}"
  fitScatter "plot-m2v01.svg" "Penguins: flipper and mass"
    "flipper length (mm)" "body mass (g)" d []
  contract "ads-lean-m2v01-v1" (cnt d > 0 && sxx d > 0)

/-- m2-02: the sums and ols defs on bill length against mass. -/
def m2Plot02 : IO Unit := do
  let d ← penguinPairs "bill_length_mm" "body_mass_g"
  IO.println s!"cnt {cnt d}, sx {sx d}, sy {sy d}"
  IO.println s!"slope: {olsSlope d}"
  fitScatter "plot-m2v02.svg" "Penguins: bill and mass"
    "bill length (mm)" "body mass (g)" d []
  contract "ads-lean-m2v02-v1" (cnt d > 0 && sxx d > 0)

/-- m2-04: the residual sum for intercepts around the fitted one
(slope fixed at the fit): the identity of `resid_sum`. -/
def m2Plot04 : IO Unit := do
  let d := flipperMass (← readCsv "../..")
  let a0 := olsIntercept d
  let b := olsSlope d
  let ks : List Int := [-3, -2, -1, 0, 1, 2, 3]
  let at_ := ks.map fun k => a0 + 200 * (k : ℚ)
  let sums := at_.map fun a => (resid d a b).sum
  IO.println s!"sum at fitted intercept: {(resid d a0 b).sum}"
  IO.println s!"identity holds: {sums == at_.map fun a =>
    sy d - cnt d * a - b * sx d}"
  writeScatter "plot-m2v04.svg" "Residual sum by intercept"
    "intercept a (g)" "sum of residuals (g)"
    ((at_.zip sums).map fun p => (qf p.1, qf p.2))
    [(qf (a0 - 600), qf ((resid d (a0 - 600) b).sum)),
     (qf (a0 + 600), qf ((resid d (a0 + 600) b).sum))]
    [(qf a0, 0)]
    [s!"n = {d.length} penguins", "sum = 0 at fitted a"]
  contract "ads-lean-m2v04-v1"
    ((resid d a0 b).sum == 0 &&
      sums == at_.map fun a => sy d - cnt d * a - b * sx d)

/-- m2-05: residuals against fitted mass; they sum to 0. -/
def m2Plot05 : IO Unit := do
  let d := flipperMass (← readCsv "../..")
  let a := olsIntercept d
  let b := olsSlope d
  let fit := fun (x : ℚ) => a + b * x
  let r := resid d a b
  IO.println s!"residuals sum: {r.sum}"
  let (lo, hi) := xSpan d
  writeScatter "plot-m2v05.svg" "Residuals against fitted mass"
    "fitted body mass (g)" "residual (g)"
    ((d.zip r).map fun (p, e) => (qf (fit p.1), qf e))
    [(qf (fit lo), 0), (qf (fit hi), 0)] []
    [s!"n = {d.length} penguins", s!"sum = {r.sum}"]
  contract "ads-lean-m2v05-v1" (d.length > 0 && r.sum == 0)

/-- m2-07: bill length against flipper length. -/
def m2Plot07 : IO Unit := do
  let d ← penguinPairs "bill_length_mm" "flipper_length_mm"
  IO.println s!"cnt {cnt d}, slope {olsSlope d}"
  fitScatter "plot-m2v07.svg" "Penguins: bill and flipper"
    "bill length (mm)" "flipper length (mm)" d []
  contract "ads-lean-m2v07-v1" (cnt d > 0 && sxx d > 0)

/-- m2-09: the true slope passes its guard on the penguins. -/
def m2Plot09 : IO Unit := do
  let d := flipperMass (← readCsv "../..")
  IO.println s!"guard true slope: {
    olsSlope d == 1145743050 / 23059877}"
  IO.println s!"guard planted slope 2: {olsSlope d == 2}"
  fitScatter "plot-m2v09.svg" "Penguins: the guarded slope"
    "flipper length (mm)" "body mass (g)" d []
  contract "ads-lean-m2v09-v1"
    (olsSlope d == 1145743050 / 23059877 && olsSlope d != 2)

/-- m2-10: bill depth against mass, the fit through the means. -/
def m2Plot10 : IO Unit := do
  let d ← penguinPairs "bill_depth_mm" "body_mass_g"
  let mx := sx d / cnt d
  let my := sy d / cnt d
  IO.println s!"mean x {mx}, mean y {my}"
  IO.println s!"line passes the means: {
    olsIntercept d + olsSlope d * mx == my}"
  fitScatter "plot-m2v10.svg" "Penguins: depth and mass"
    "bill depth (mm)" "body mass (g)" d [(qf mx, qf my)]
  contract "ads-lean-m2v10-v1"
    (cnt d > 0 && olsIntercept d + olsSlope d * mx == my)

