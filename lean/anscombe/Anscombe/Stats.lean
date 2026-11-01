/-! Anscombe's quartet (ADS-DEMO-001): parse, summary, report.
Core Lean only: no Mathlib, no network, no clock. -/

namespace Anscombe

/-- The four named sets of (x, y) points, in file order. -/
abbrev Sets := List (String × List (Float × Float))

def names : List String := ["I", "II", "III", "IV"]

/-- A decimal such as `8.04` or `10`: digits, an optional point and
more digits. Exact numerator over a power of ten, one division. -/
def parseDec (s : String) : Option Float :=
  match s.splitOn "." with
  | [i] => i.toNat?.map Nat.toFloat
  | [i, f] =>
    match i.toNat?, f.toNat? with
    | some a, some b =>
      if f.isEmpty then none
      else
        let k := 10 ^ f.length
        some ((a * k + b).toFloat / k.toFloat)
    | _, _ => none
  | _ => none

/-- Parse `set,x,y` rows (header first) into the four sets. -/
def parse (csv : String) : Except String Sets := do
  let mut out : Sets := names.map (·, [])
  for (line, i) in (csv.splitOn "\n").zipIdx do
    if i == 0 || line.isEmpty then continue
    let n := i + 1
    match line.splitOn "," with
    | [s, x, y] =>
      let some xv := parseDec x | throw s!"line {n}: bad x"
      let some yv := parseDec y | throw s!"line {n}: bad y"
      unless names.contains s do throw s!"line {n}: unknown set {s}"
      out := out.map fun (k, p) =>
        if k == s then (k, p ++ [(xv, yv)]) else (k, p)
    | _ => throw s!"line {n}: want 3 fields"
  return out

/-- (mean x, mean y, slope, intercept, correlation) of one set. -/
def stats (p : List (Float × Float)) :
    Float × Float × Float × Float × Float :=
  let n := p.length.toFloat
  let mx := (p.foldl (fun a q => a + q.1) 0) / n
  let my := (p.foldl (fun a q => a + q.2) 0) / n
  let sxx := p.foldl (fun a q => a + (q.1 - mx) * (q.1 - mx)) 0
  let syy := p.foldl (fun a q => a + (q.2 - my) * (q.2 - my)) 0
  let sxy := p.foldl (fun a q => a + (q.1 - mx) * (q.2 - my)) 0
  let b := sxy / sxx
  (mx, my, b, my - b * mx, sxy / (sxx * syy).sqrt)

/-- A float with two decimals, rounded to nearest. -/
def fmt2 (x : Float) : String :=
  let c := (x.abs * 100).round.toUInt64.toNat
  let frac := toString (c % 100)
  (if x < 0 then "-" else "") ++ toString (c / 100) ++ "." ++
    (if frac.length < 2 then "0" ++ frac else frac)

/-- One summary line per set: the stdout every language prints. -/
def report (sets : Sets) : String :=
  String.join <| sets.map fun (name, p) =>
    let (mx, my, b, a, r) := stats p
    s!"set {name}: n={p.length} mean_x={fmt2 mx} " ++
    s!"mean_y={fmt2 my} slope={fmt2 b} intercept={fmt2 a} " ++
    s!"r={fmt2 r}\n"

/-- The part of a report line after `set X: n=N `. -/
def tail (line : String) : String :=
  ((line.splitOn "mean_x=").getD 1 "")

/-- All four sets share one summary (the point of the quartet). -/
def agree (text : String) : Bool :=
  let ts := ((text.splitOn "\n").filter (· ≠ "")).map tail
  ts.length == 4 && ts.all (· == ts.headD "")

end Anscombe
