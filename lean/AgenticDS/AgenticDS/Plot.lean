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

/-- XML text escape: the three reserved characters. -/
def esc (s : String) : String :=
  ((s.replace "&" "&amp;").replace "<" "&lt;").replace ">" "&gt;"

/-- A label without its padding spaces, escaped. -/
def lbl (s : String) : String := esc s.trimAscii.toString

/-- Left edge of the bars: after the longest label. -/
def barX (rows : List (String × Nat)) : Nat :=
  1070 + 22 * ((rows.map fun r => (lbl r.1).length).foldl max 0)

/-- Longest bar in pixels, leaving room for the count. -/
def barMax (rows : List (String × Nat)) : Nat := 1700 - barX rows

/-- One SVG row: label, a bar of `barMax * width / w` pixels, the
count. -/
def svgRow (x0 px w m : Nat) (i : Nat) (r : String × Nat) :
    String :=
  let y := 190 + 80 * i
  let k := px * width w m r.2 / w
  s!"<text x=\"1020\" y=\"{y + 38}\" font-size=\"36\" " ++
  s!"fill=\"#e5e7eb\">{lbl r.1}</text>\n" ++
  s!"<rect x=\"{x0}\" y=\"{y}\" width=\"{k}\" height=\"48\" " ++
  s!"fill=\"#4ade80\"/>\n" ++
  s!"<text x=\"{x0 + 30 + k}\" y=\"{y + 38}\" font-size=\"36\" " ++
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
  s!"<title id=\"t\">{esc title}</title>\n" ++
  s!"<desc id=\"d\">Bar chart, one bar per row.</desc>\n" ++
  "<rect width=\"1920\" height=\"1080\" fill=\"#0b1020\"/>\n" ++
  s!"<text x=\"1020\" y=\"110\" font-size=\"44\" " ++
  s!"fill=\"#e5e7eb\">{esc title}</text>\n" ++
  String.join (rows.zipIdx.map fun (r, i) =>
    svgRow (barX rows) (barMax rows) w m i r) ++
  "</svg>\n"

/-- Write the SVG for `rows`, then check the contract
`plot_svg_bounded`: a non-empty chart, one rect per row plus
the background, and no bar leaves the picture. -/
def writeSvg (path : System.FilePath) (title : String) (w : Nat)
    (rows : List (String × Nat)) : IO Unit := do
  let s := plotSvg title w rows
  IO.FS.writeFile path s
  let m := (rows.map (·.2)).foldl max 0
  let n := (s.splitOn "<rect").length - 1
  let bad := rows.isEmpty || n != rows.length + 1 ||
    (s.splitOn "<text").length - 1 != 2 * rows.length + 1 ||
    190 + 80 * rows.length - 32 > 1080 ||
    !(rows.all fun (_, c) =>
      barX rows + barMax rows * width w m c / w ≤ 1700)
  if bad then
    throw (IO.userError "plot_svg_bounded violated")
  IO.println s!"svg {rows.length} bars {path}"
  IO.println "contract: plot_svg_bounded OK"

end AgenticDS
