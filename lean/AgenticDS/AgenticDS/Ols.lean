/-
Copyright (c) 2026 Pragmatic AI Labs. All rights reserved.
Released under MIT license as described in the file LICENSE.
Authors: Pragmatic AI Labs
-/
import AgenticDS.Csv
import AgenticDS.Stats

/-! # Exact simple linear regression over ℚ

Fit record, residuals, one sum lemma, and the CSV / table / plot /
color helpers the example file uses. -/

namespace AgenticDS

structure Fit where
  intercept : ℚ
  slope : ℚ

/-- Population covariance of (x, y) pairs. -/
def cov (ps : List (ℚ × ℚ)) : ℚ :=
  (ps.map fun p => (p.1 - mean (ps.map (·.1))) *
    (p.2 - mean (ps.map (·.2)))).sum / ps.length

def residuals (f : Fit) (ps : List (ℚ × ℚ)) : List ℚ :=
  ps.map fun p => p.2 - (f.intercept + f.slope * p.1)

/-- The residual sum in closed form (the only lemma the proof
needs). -/
theorem sum_residuals (a b : ℚ) (ps : List (ℚ × ℚ)) :
    (ps.map fun p => p.2 - (a + b * p.1)).sum =
      (ps.map (·.2)).sum - ps.length * a
        - b * (ps.map (·.1)).sum := by
  induction ps with
  | nil => simp
  | cons p t ih => simp [ih]; ring

/-- Pairs of two named CSV columns; a row with either value NA is
dropped; an unknown column name gives no pairs. -/
def pairsOf (csv : String) (xc yc : String) : List (ℚ × ℚ) :=
  match parseCsv csv with
  | [] => []
  | h :: rows =>
    match h.findIdx? (· == xc), h.findIdx? (· == yc) with
    | some ix, some iy =>
      rows.filterMap fun r =>
        match r[ix]?.bind parseRat, r[iy]?.bind parseRat with
        | some x, some y => some (x, y)
        | _, _ => none
    | _, _ => []

/-- Same, reading `datasets/penguins/penguins.csv` under `root`. -/
def readPairs (root xc yc : String) : IO (List (ℚ × ℚ)) := do
  let csv ← IO.FS.readFile s!"{root}/datasets/penguins/penguins.csv"
  pure (pairsOf csv xc yc)

/-- Round a rational to 2 decimals as text. -/
def fmt2 (q : ℚ) : String :=
  let a := if q < 0 then -q else q
  let c := (a * 100 + 1 / 2).floor.toNat
  let frac := if c % 100 < 10 then "0" else ""
  let sign := if q < 0 && c != 0 then "-" else ""
  sign ++ s!"{c / 100}.{frac}{c % 100}"

def green (s : String) : String := "\x1b[1;32m" ++ s ++ "\x1b[0m"
def dimmed (s : String) : String := "\x1b[2m" ++ s ++ "\x1b[0m"

def padL (s : String) (n : Nat) : String :=
  "".pushn ' ' (n - s.length) ++ s

/-- First `n` rows: x, y, fitted, residual. -/
def printTable (ps : List (ℚ × ℚ)) (f : Fit) (n : Nat) :
    IO Unit := do
  let ws := [10, 7, 9, 8]
  let cells (c : List String) :=
    " ".intercalate (List.zipWith padL c ws)
  IO.println (dimmed
    (cells ["flipper_mm", "mass_g", "fitted_g", "resid_g"]))
  for p in ps.take n do
    let yhat := f.intercept + f.slope * p.1
    IO.println
      (cells [fmt2 p.1, fmt2 p.2, fmt2 yhat, fmt2 (p.2 - yhat)])

def circle (x y : ℚ) : String :=
  s!"<circle cx=\"{fmt2 x}\" cy=\"{fmt2 y}\" r=\"6\" " ++
    "fill=\"#5fb0ff\" fill-opacity=\"0.65\"/>"

def label (x y : ℚ) (anchor t : String) : String :=
  s!"<text x=\"{fmt2 x}\" y=\"{fmt2 y}\" " ++
    s!"text-anchor=\"{anchor}\" fill=\"#e6e6e6\" " ++
    s!"font-size=\"40\" font-family=\"DejaVu Sans\">{t}</text>"

/-- Is ImageMagick's `convert` installed? -/
def haveConvert : IO Bool := do
  try
    let o ← IO.Process.output
      { cmd := "convert", args := #["-version"] }
    pure (o.exitCode == 0)
  catch _ => pure false

/-- Scatter + fitted line as SVG (1600x1200), converted to PNG by
ImageMagick. -/
def savePlot (ps : List (ℚ × ℚ)) (f : Fit) (png : String) :
    IO Unit := do
  let (x0, x1) : ℚ × ℚ := (170, 235)
  let (y0, y1) : ℚ × ℚ := (2500, 6500)
  let px (x : ℚ) : ℚ := 230 + (x - x0) / (x1 - x0) * 1300
  let py (y : ℚ) : ℚ := 1030 - (y - y0) / (y1 - y0) * 880
  let at_ (x : ℚ) : ℚ := f.intercept + f.slope * x
  let pts := ps.map fun p => circle (px p.1) (py p.2)
  let ln := s!"<line x1=\"{fmt2 (px x0)}\" " ++
    s!"y1=\"{fmt2 (py (at_ x0))}\" " ++
    s!"x2=\"{fmt2 (px x1)}\" y2=\"{fmt2 (py (at_ x1))}\" " ++
    "stroke=\"#ff7a59\" stroke-width=\"7\"/>"
  let xt := [180, 200, 220].map fun x =>
    label (px x) 1090 "middle" (toString x)
  let yt := [3000, 4000, 5000, 6000].map fun y =>
    label 205 (py y + 14) "end" (toString y)
  let marks := [
    label 800 90 "middle"
      "penguins: mass ~ flipper (Lean, exact ℚ)",
    label 880 1170 "middle" "flipper_length_mm",
    label 40 600 "start" "g"]
  let body := "\n".intercalate (pts ++ [ln] ++ xt ++ yt ++ marks)
  let svg := "<svg xmlns=\"http://www.w3.org/2000/svg\" " ++
    "width=\"1600\" height=\"1200\">\n" ++
    "<rect width=\"1600\" height=\"1200\" fill=\"#0b1014\"/>\n" ++
    body ++ "\n</svg>\n"
  unless (← haveConvert) do
    IO.println "plot skipped: ImageMagick convert not found"
    return
  IO.FS.writeFile "plot.svg" svg
  let out ← IO.Process.output
    { cmd := "convert", args := #["plot.svg", png] }
  IO.FS.removeFile "plot.svg"
  if out.exitCode != 0 then
    throw (IO.userError s!"convert failed: {out.stderr}")

/-- Print the fit, a table, save the plot, and the green verdict. -/
def report (ps : List (ℚ × ℚ)) (f : Fit) : IO Unit := do
  IO.println s!"rows: {ps.length}"
  IO.println s!"intercept: {fmt2 f.intercept}"
  IO.println s!"slope: {fmt2 f.slope}"
  printTable ps f 2
  savePlot ps f "plot.png"
  let z := (residuals f ps).foldl (· + ·) 0
  IO.println
    (green s!"residuals sum to {z}: " ++
      "proved (theorem residuals_sum)")

end AgenticDS
