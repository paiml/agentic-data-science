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



/-! ## Scatter and line plots

Real axes: a frame, numeric ticks, light gridlines, titled axes,
monospace text. The points are the numbers the demo computed. -/

/-- A float with one decimal, no exponent. -/
def fmt1 (x : Float) : String :=
  let neg := x < 0
  let t := (Float.abs x * 10).round.toUInt64.toNat
  let s := s!"{t / 10}.{t % 10}"
  if neg && t != 0 then "-" ++ s else s

/-- Plot box in pixels: left, right, top, bottom. -/
def bx0 : Float := 1130
def bx1 : Float := 1850
def by0 : Float := 190
def by1 : Float := 880

/-- Range of a list padded so a flat series still has width. -/
def rng (l : List Float) : Float × Float :=
  let lo := l.foldl min (l.headD 0)
  let hi := l.foldl max (l.headD 0)
  let pad := if hi - lo < 1e-9 then 1 else (hi - lo) / 20
  -- non-negative data never gets a negative tick (a count axis)
  let lo' := if lo >= 0 then max 0 (lo - pad) else lo - pad
  (lo', hi + pad)

/-- Pixel x of a data x. -/
def pxOf (r : Float × Float) (x : Float) : Float :=
  bx0 + (x - r.1) / (r.2 - r.1) * (bx1 - bx0)

/-- Pixel y of a data y (up is smaller). -/
def pyOf (r : Float × Float) (y : Float) : Float :=
  by1 - (y - r.1) / (r.2 - r.1) * (by1 - by0)

/-- Dot radius: small when there are many points. -/
def dotR (pts : List (Float × Float)) : Nat :=
  if pts.length > 60 then 4 else 9

/-- A rational as a float. -/
def qf (q : ℚ) : Float := Float.ofInt q.num / Float.ofNat q.den

def mono : String :=
  "font-family=\"DejaVu Sans Mono, monospace\" "

/-- Gridline plus label at tick `i` of 5 on both axes. -/
def tickSvg (rx ry : Float × Float) (i : Nat) : String :=
  let f := i.toFloat / 4
  let gx := bx0 + f * (bx1 - bx0)
  let gy := by1 - f * (by1 - by0)
  let vx := rx.1 + f * (rx.2 - rx.1)
  let vy := ry.1 + f * (ry.2 - ry.1)
  s!"<path d=\"M{gx} {by0}V{by1}M{bx0} {gy}H{bx1}\" " ++
  "stroke=\"#334155\" stroke-width=\"1\" fill=\"none\"/>\n" ++
  s!"<text x=\"{gx - 36}\" y=\"{by1 + 40}\" {mono}" ++
  s!"font-size=\"28\" fill=\"#cbd5e1\">{fmt1 vx}</text>\n" ++
  s!"<text x=\"{bx0 - 100}\" y=\"{gy + 10}\" {mono}" ++
  s!"font-size=\"28\" fill=\"#cbd5e1\">{fmt1 vy}</text>\n"

def dotSvg (r : Nat) (rx ry : Float × Float) (col : String)
    (p : Float × Float) : String :=
  s!"<circle cx=\"{pxOf rx p.1}\" " ++
  s!"cy=\"{pyOf ry p.2}\" r=\"{r}\" " ++
  s!"fill=\"{col}\"/>\n"

/-- Scatter of `pts`, an optional `line` through data points, and
optional `marks` (centroids) in a second colour. -/
def scatterSvg (title xl yl : String) (pts line marks :
    List (Float × Float)) (notes : List String) : String :=
  let all := pts ++ line ++ marks
  let rx := rng (all.map (·.1))
  let ry := rng (all.map (·.2))
  let lp := String.intercalate " " (line.map fun p =>
    s!"{pxOf rx p.1},{pyOf ry p.2}")
  "<svg xmlns=\"http://www.w3.org/2000/svg\" " ++
  "width=\"1920\" height=\"1080\" viewBox=\"0 0 1920 1080\" " ++
  "role=\"img\" aria-labelledby=\"t d\">\n" ++
  "<!-- GRID PROTOCOL MANIFEST: 1920x1080, plot in the right " ++
  "half, the left half is for the terminal -->\n" ++
  s!"<title id=\"t\">{esc title}</title>\n" ++
  s!"<desc id=\"d\">Scatter plot with axes and ticks.</desc>\n" ++
  "<rect width=\"1920\" height=\"1080\" fill=\"#0b1020\"/>\n" ++
  s!"<text x=\"1000\" y=\"110\" {mono}font-size=\"40\" " ++
  s!"fill=\"#e5e7eb\">{esc title}</text>\n" ++
  String.join ((List.range 5).map (tickSvg rx ry)) ++
  s!"<path d=\"M{bx0} {by0}V{by1}H{bx1}\" stroke=\"#94a3b8\" " ++
  "stroke-width=\"3\" fill=\"none\"/>\n" ++
  s!"<text x=\"{bx0}\" y=\"960\" {mono}font-size=\"30\" " ++
  s!"fill=\"#e5e7eb\">{esc xl}</text>\n" ++
  s!"<text x=\"1000\" y=\"165\" {mono}font-size=\"30\" " ++
  s!"fill=\"#e5e7eb\">{esc yl}</text>\n" ++
  (if line.length > 1 then
    s!"<polyline points=\"{lp}\" fill=\"none\" " ++
    "stroke=\"#f59e0b\" stroke-width=\"5\"/>\n"
  else "") ++
  String.join (notes.zipIdx.map fun (n, i) =>
    s!"<text x=\"40\" y=\"{700 + 44 * i}\" {mono}" ++
    s!"font-size=\"30\" fill=\"#cbd5e1\">{esc n}</text>\n") ++
  String.join (pts.map (dotSvg (dotR pts) rx ry "#4ade80")) ++
  String.join (marks.map (dotSvg 11 rx ry "#f87171")) ++
  "</svg>\n"

/-- Write the scatter SVG, then check `plot_scatter_bounded` and
`plot_scatter_source` (every plotted point is its row of `src`):
at least one point, one circle per point and mark, and every
circle inside the plot box. -/
def writeScatterChecked (path : System.FilePath)
    (title xl yl : String)
    (pts line marks : List (Float × Float))
    (notes : List String)
    (src : Option (List (Float × Float))) : IO Unit := do
  let s := scatterSvg title xl yl pts line marks notes
  IO.FS.writeFile path s
  let all := pts ++ line ++ marks
  let rx := rng (all.map (·.1))
  let ry := rng (all.map (·.2))
  let inside := fun (p : Float × Float) =>
    bx0 ≤ pxOf rx p.1 && pxOf rx p.1 ≤ bx1 &&
    by0 ≤ pyOf ry p.2 && pyOf ry p.2 ≤ by1
  let n := (s.splitOn "<circle").length - 1
  let bad := pts.isEmpty || n != pts.length + marks.length ||
    !(all.all inside)
  if bad then
    throw (IO.userError "plot_scatter_bounded violated")
  -- Each plotted point is its source row, compared as data.
  let same := match src with
    | none => true
    | some s => pts.length == s.length &&
      (pts.zip s).all fun (a, b) => a.1 == b.1 && a.2 == b.2
  if !same then
    throw (IO.userError "plot_scatter_source violated")
  IO.println s!"svg {pts.length} points {path}"
  IO.println "contract: plot_scatter_bounded OK"
  IO.println (if src.isSome then "contract: plot_scatter_source OK"
    else "plot_scatter_source: derived, no independent source")

/-- A scatter whose points are checked against independent source
rows `src` (read from the data file, not from the plotted list). -/
def writeScatter (path : System.FilePath) (title xl yl : String)
    (pts line marks : List (Float × Float))
    (notes : List String) (src : List (Float × Float)) :
    IO Unit :=
  writeScatterChecked path title xl yl pts line marks notes
    (some src)

/-- A scatter of derived or synthetic data: it has no independent
source rows, so it checks bounds only and says so. -/
def writeScatterDerived (path : System.FilePath)
    (title xl yl : String)
    (pts line marks : List (Float × Float))
    (notes : List String) : IO Unit :=
  writeScatterChecked path title xl yl pts line marks notes none


/-- A decimal such as `39.1` or `7`, read as digits over a
power of ten. Its own parser, apart from the pipeline's. -/
def rawDec (s : String) : Option Float :=
  match s.splitOn "." with
  | [a] => a.toNat?.map Float.ofNat
  | [a, b] => (a ++ b).toNat?.map fun i =>
      Float.ofNat i / Float.ofNat (10 ^ b.length)
  | _ => none

/-- Two named columns of a comma-separated file, straight
from its text: rows where either cell is not a number are
dropped. Independent of the pipeline's parser and cleaning. -/
def rawPairs (path : String) (xc yc : String) :
    IO (List (Float × Float)) := do
  let ls := ((← IO.FS.readFile path).splitOn "\n").map
    (·.replace "\r" "") |>.filter (· != "")
  match ls with
  | [] => pure []
  | h :: rows =>
    let hs := h.splitOn ","
    match hs.findIdx? (· == xc), hs.findIdx? (· == yc) with
    | some ix, some iy =>
      pure <| rows.filterMap fun r =>
        let c := r.splitOn ","
        match (c.drop ix).head?.bind rawDec,
            (c.drop iy).head?.bind rawDec with
        | some x, some y => some (x, y)
        | _, _ => none
    | _, _ => pure []

/-- Every `stride`-th row, counting from the first. -/
def everyNth {α : Type} (stride : Nat) (l : List α) : List α :=
  (l.zipIdx.filter fun p => p.2 % stride == 0).map (·.1)

/-- Smallest 1, 2 or 5 times a power of ten that is at least a
quarter of `m`: the whole-number tick step of the count axis. -/
def niceStep (m : Nat) : Nat :=
  let need := max 1 ((m + 3) / 4)
  let cands := (List.range 12).flatMap fun k =>
    [1, 2, 5].map (· * 10 ^ k)
  (cands.find? (· ≥ need)).getD need

/-- Plot box of the bar chart: left, right, top, bottom. -/
def cx0 : Float := 1130
def cx1 : Float := 1850
def cy0 : Float := 190
def cy1 : Float := 880

/-- Widest label, in characters, that a slot of `n` bars holds
at font size 26 (16 px a character). -/
def slotChars (n : Nat) : Nat := (720 / (max n 1)) / 16

/-- Height of the bar of count `c` when the tallest is `m`. -/
def barH (m c : Nat) : Float :=
  (cy1 - cy0) * c.toFloat / (4 * niceStep m).toFloat

/-- One bar: rect, centred label under the axis, centred count
above the bar. -/
def barSvg (n m : Nat) (i : Nat) (r : String × Nat) : String :=
  let slot := (cx1 - cx0) / n.toFloat
  let x := cx0 + slot * i.toFloat + slot * 0.2
  let mid := cx0 + slot * (i.toFloat + 0.5)
  let h := barH m r.2
  s!"<rect x=\"{x}\" y=\"{cy1 - h}\" width=\"{slot * 0.6}\" " ++
  s!"height=\"{h}\" fill=\"#4ade80\"/>\n" ++
  s!"<text x=\"{mid}\" y=\"{cy1 + 40}\" text-anchor=\"middle\" " ++
  s!"{mono}font-size=\"26\" fill=\"#cbd5e1\">{lbl r.1}</text>\n" ++
  s!"<text x=\"{mid}\" y=\"{cy1 - h - 14}\" " ++
  "text-anchor=\"middle\" " ++
  s!"{mono}font-size=\"28\" fill=\"#e5e7eb\">{r.2}</text>\n"

/-- Gridline plus label at tick `i` of 5 on the count axis. -/
def barTick (m : Nat) (i : Nat) : String :=
  let f := i.toFloat / 4
  let gy := cy1 - f * (cy1 - cy0)
  s!"<path d=\"M{cx0} {gy}H{cx1}\" stroke=\"#334155\" " ++
  "stroke-width=\"1\" fill=\"none\"/>\n" ++
  s!"<text x=\"{cx0 - 20}\" y=\"{gy + 10}\" text-anchor=\"end\" " ++
  s!"{mono}font-size=\"28\" fill=\"#cbd5e1\">" ++
  s!"{i * niceStep m}</text>\n"

/-- The rows as a bar chart with real axes, 1920 by 1080: a frame, a
count axis from zero with five ticks and gridlines, one bar per row
with its label and count, filling the right half. -/
def plotSvg (title : String) (_w : Nat)
    (rows : List (String × Nat)) : String :=
  let m := (rows.map (·.2)).foldl max 0
  let n := rows.length
  "<svg xmlns=\"http://www.w3.org/2000/svg\" " ++
  "width=\"1920\" height=\"1080\" viewBox=\"0 0 1920 1080\" " ++
  "role=\"img\" aria-labelledby=\"t d\">\n" ++
  "<!-- GRID PROTOCOL MANIFEST: 1920x1080, plot in the right " ++
  "half, the left half is for the terminal -->\n" ++
  s!"<title id=\"t\">{esc title}</title>\n" ++
  "<desc id=\"d\">Bar chart with a count axis.</desc>\n" ++
  "<rect width=\"1920\" height=\"1080\" fill=\"#0b1020\"/>\n" ++
  s!"<text x=\"1000\" y=\"110\" {mono}font-size=\"40\" " ++
  s!"fill=\"#e5e7eb\">{esc title}</text>\n" ++
  s!"<text x=\"1000\" y=\"165\" {mono}font-size=\"30\" " ++
  "fill=\"#e5e7eb\">count</text>\n" ++
  String.join ((List.range 5).map (barTick m)) ++
  s!"<path d=\"M{cx0} {cy0}V{cy1}H{cx1}\" stroke=\"#94a3b8\" " ++
  "stroke-width=\"3\" fill=\"none\"/>\n" ++
  String.join (rows.zipIdx.map fun (r, i) => barSvg n m i r) ++
  "</svg>\n"

/-- Write the SVG for `rows`, then check the contract
`plot_svg_bounded`: a non-empty chart, one rect per row plus the
background, at most eight bars, seven texts plus two per row,
every label fits its slot, and no bar leaves the plot box. -/
def writeSvg (path : System.FilePath) (title : String) (w : Nat)
    (rows : List (String × Nat)) : IO Unit := do
  let s := plotSvg title w rows
  IO.FS.writeFile path s
  let m := (rows.map (·.2)).foldl max 0
  let n := rows.length
  let bad := rows.isEmpty || m == 0 || n > 8 ||
    (s.splitOn "<rect").length - 1 != n + 1 ||
    (s.splitOn "<text").length - 1 != 2 * n + 7 ||
    !(rows.all fun (l, c) =>
      (lbl l).length ≤ slotChars n && c ≤ m &&
      barH m c ≤ cy1 - cy0)
  if bad then
    throw (IO.userError "plot_svg_bounded violated")
  IO.println s!"svg {n} bars {path}"
  IO.println "contract: plot_svg_bounded OK"


/-- Column of a data x on a grid `w` cells wide. -/
def tsCol (w : Nat) (r : Float × Float) (x : Float) : Nat :=
  min (w - 1)
    ((x - r.1) / (r.2 - r.1) * (w - 1).toFloat + 0.5).toUInt64.toNat

/-- Row of a data y on a grid `h` cells tall (row 0 is the top). -/
def tsRow (h : Nat) (r : Float × Float) (y : Float) : Nat :=
  (h - 1) - min (h - 1)
    ((y - r.1) / (r.2 - r.1) * (h - 1).toFloat + 0.5).toUInt64.toNat

/-- The grid: `●` for a point, `·` for the fitted line `a + b x`,
one string per row, `h` rows of `w` cells. -/
def textGrid (w h : Nat) (pts : List (Float × Float))
    (a b : Float) : List String :=
  let rx := rng (pts.map (·.1))
  let ry := rng (pts.map (·.2))
  let dots := pts.map fun p => (tsRow h ry p.2, tsCol w rx p.1)
  let lineAt := fun (c : Nat) =>
    tsRow h ry (a + b * (rx.1 + c.toFloat / (w - 1).toFloat *
      (rx.2 - rx.1)))
  (List.range h).map fun r =>
    String.ofList ((List.range w).map fun c =>
      if dots.contains (r, c) then '●'
      else if lineAt c == r then '·' else ' ')

/-- The grid has exactly `h` rows. -/
theorem textGrid_rows (w h : Nat) (pts : List (Float × Float))
    (a b : Float) : (textGrid w h pts a b).length = h := by
  simp [textGrid]

/-- Print a scatter of the points with its fitted line on the
screen, then check `plot_text_scatter_bounded`: `h` rows of `w`
cells, at least one point and one line cell drawn. -/
def textScatter (w h : Nat) (xl yl : String)
    (pts : List (Float × Float)) (a b : Float) : IO Unit := do
  let g := textGrid w h pts a b
  let rx := rng (pts.map (·.1))
  let ry := rng (pts.map (·.2))
  IO.println s!"{yl}: {ry.2.round} (top) to {ry.1.round} (bottom)"
  for row in g do IO.println s!"│{row}"
  IO.println s!"└{String.ofList (List.replicate w '─')}"
  IO.println s!"{xl}: {rx.1.round} to {rx.2.round}"
  let cnt := fun (ch : Char) =>
    g.foldl (fun n s => n + (s.toList.filter (· == ch)).length) 0
  let ok := g.length == h && g.all (·.length == w) &&
    0 < cnt '●' && cnt '●' ≤ pts.length && 0 < cnt '·'
  if !ok then
    throw (IO.userError "plot_text_scatter_bounded violated")
  IO.println s!"text plot {pts.length} points {cnt '●'} cells"
  IO.println "contract: plot_text_scatter_bounded OK"

end AgenticDS
