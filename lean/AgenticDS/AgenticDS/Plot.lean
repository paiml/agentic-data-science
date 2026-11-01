/-
Copyright (c) 2026 Pragmatic AI Labs. All rights reserved.
Released under MIT license as described in the file LICENSE.
Authors: Pragmatic AI Labs
-/
import Mathlib

/-! # Text plots: block-character bars

A bar is `n` copies of `█`, so its length is its value. `width`
scales a count into a bar of at most `w` blocks, never zero for a
nonzero count. `plot` prints the rows and checks the contract
`plot_bars_bounded` before it says so. -/

namespace AgenticDS

/-- A bar of `n` full blocks. -/
def bar (n : Nat) : String := String.ofList (List.replicate n '█')

/-- The bar holds exactly as many blocks as its value. -/
theorem bar_length (n : Nat) : (bar n).length = n := by
  simp [bar]

/-- Blocks for count `n` when the largest count `m` gets `w`
blocks; a nonzero count always shows at least one block. -/
def width (w m n : Nat) : Nat :=
  if n = 0 then 0 else max 1 (n * w / max m 1)

/-- Print a bar and its count for each row, then check the
contract: no bar is longer than `w`, zero shows nothing, nonzero
shows something, and the longest count fills the width. -/
def plot (w : Nat) (rows : List (String × Nat)) : IO Unit := do
  let m := (rows.map (·.2)).foldl max 0
  for (l, n) in rows do
    IO.println s!"{l} {bar (width w m n)} {n}"
  let ok := rows.all fun (_, n) =>
    let k := width w m n
    k ≤ w && (n = 0) == (k = 0) && (n ≠ m || k = w)
  assert! ok
  IO.println "contract: plot_bars_bounded OK"

/-- One SVG row: label, a bar of `25 * width` pixels, the count. -/
def svgRow (w m : Nat) (i : Nat) (r : String × Nat) : String :=
  let y := 190 + 80 * i
  let k := 25 * width w m r.2
  s!"<text x=\"1020\" y=\"{y + 38}\" font-size=\"36\" " ++
  s!"fill=\"#e5e7eb\">{r.1}</text>\n" ++
  s!"<rect x=\"1100\" y=\"{y}\" width=\"{k}\" height=\"48\" " ++
  s!"fill=\"#4ade80\"/>\n" ++
  s!"<text x=\"{1120 + k}\" y=\"{y + 38}\" font-size=\"36\" " ++
  s!"fill=\"#e5e7eb\">{r.2}</text>\n"

/-- The same rows as an SVG picture, 1920 by 1080, plot on the
right half, one rect per bar and one for the background. -/
def plotSvg (title : String) (w : Nat)
    (rows : List (String × Nat)) : String :=
  let m := (rows.map (·.2)).foldl max 0
  "<svg xmlns=\"http://www.w3.org/2000/svg\" " ++
  "width=\"1920\" height=\"1080\" viewBox=\"0 0 1920 1080\" " ++
  "role=\"img\" aria-labelledby=\"t d\">\n" ++
  "<!-- GRID PROTOCOL MANIFEST: 1920x1080, plot in the right " ++
  "half, the left half is for the terminal -->\n" ++
  s!"<title id=\"t\">{title}</title>\n" ++
  s!"<desc id=\"d\">Bar chart, one bar per row.</desc>\n" ++
  "<rect width=\"1920\" height=\"1080\" fill=\"#0b1020\"/>\n" ++
  s!"<text x=\"1020\" y=\"110\" font-size=\"44\" " ++
  s!"fill=\"#e5e7eb\">{title}</text>\n" ++
  String.join (rows.zipIdx.map fun (r, i) => svgRow w m i r) ++
  "</svg>\n"

/-- Write the SVG for `rows`, then check the contract
`plot_svg_bounded`: one rect per row plus the background, and no
bar leaves the picture. -/
def writeSvg (path : System.FilePath) (title : String) (w : Nat)
    (rows : List (String × Nat)) : IO Unit := do
  let s := plotSvg title w rows
  IO.FS.writeFile path s
  let m := (rows.map (·.2)).foldl max 0
  let n := (s.splitOn "<rect").length - 1
  assert! n == rows.length + 1
  assert! rows.all fun (_, c) => 1100 + 25 * width w m c ≤ 1760
  IO.println s!"svg {rows.length} bars {path}"
  IO.println "contract: plot_svg_bounded OK"

end AgenticDS
