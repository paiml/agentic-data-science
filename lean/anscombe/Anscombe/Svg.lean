import Anscombe.Stats
/-! The SVG writer: four panels, 960 x 720, fixed fonts and colours,
no clock, no randomness. Points are blue, the fit line is red. -/

namespace Anscombe

def width : Nat := 960
def height : Nat := 720

/-- Panel plot box inside a 480 x 360 cell. -/
def px0 : Float := 40
def px1 : Float := 460
def py0 : Float := 30
def py1 : Float := 320

def xPix (cx x : Float) : Float := cx + px0 + x / 20 * (px1 - px0)
def yPix (cy y : Float) : Float := cy + py1 - y / 14 * (py1 - py0)

def circle (cx cy : Float) (p : Float × Float) : String :=
  s!"<circle cx=\"{fmt2 (xPix cx p.1)}\" " ++
  s!"cy=\"{fmt2 (yPix cy p.2)}\" r=\"4\" fill=\"#1f77b4\"/>\n"

def xTick (cx cy : Float) (v : Nat) : String :=
  s!"<text x=\"{fmt2 (xPix cx v.toFloat)}\" " ++
  s!"y=\"{fmt2 (cy + py1 + 14)}\" font-size=\"10\" " ++
  s!"text-anchor=\"middle\">{v}</text>\n"

def yTick (cx cy : Float) (v : Nat) : String :=
  s!"<text x=\"{fmt2 (cx + px0 - 6)}\" " ++
  s!"y=\"{fmt2 (yPix cy v.toFloat)}\" font-size=\"10\" " ++
  s!"text-anchor=\"end\">{v}</text>\n"

def panel (cx cy : Float) (name : String)
    (p : List (Float × Float)) : String :=
  let (_, _, b, a, _) := stats p
  let l := fun x => (xPix cx x, yPix cy (a + b * x))
  let (x1, y1) := l 3
  let (x2, y2) := l 19
  s!"<text x=\"{fmt2 (cx + 240)}\" y=\"{fmt2 (cy + 20)}\" " ++
  s!"font-size=\"16\" text-anchor=\"middle\">Set {name}</text>\n" ++
  s!"<rect x=\"{fmt2 (cx + px0)}\" y=\"{fmt2 (cy + py0)}\" " ++
  s!"width=\"{fmt2 (px1 - px0)}\" height=\"{fmt2 (py1 - py0)}\" " ++
  "fill=\"none\" stroke=\"#000000\"/>\n" ++
  String.join ((List.range 5).map fun i => xTick cx cy (i * 5)) ++
  String.join ((List.range 3).map fun i => yTick cx cy (i * 7)) ++
  String.join (p.map (circle cx cy)) ++
  s!"<line x1=\"{fmt2 x1}\" y1=\"{fmt2 y1}\" x2=\"{fmt2 x2}\" " ++
  s!"y2=\"{fmt2 y2}\" stroke=\"#d62728\" stroke-width=\"2\"/>\n"

/-- The whole picture. A set count other than four is refused. -/
def plotSvg (sets : Sets) : Except String String := do
  unless sets.length == 4 do throw "want four sets"
  let cells := sets.zipIdx.map fun ((n, p), i) =>
    panel (480 * (i % 2).toFloat) (360 * (i / 2).toFloat) n p
  return "<svg xmlns=\"http://www.w3.org/2000/svg\" " ++
    s!"width=\"{width}\" height=\"{height}\" " ++
    s!"viewBox=\"0 0 {width} {height}\" " ++
    "font-family=\"sans-serif\">\n" ++
    s!"<rect width=\"{width}\" height=\"{height}\" " ++
    "fill=\"#ffffff\"/>\n" ++ String.join cells ++ "</svg>\n"

end Anscombe
