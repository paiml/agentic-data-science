import Anscombe
/-! Tests for every function in Anscombe.Stats and Anscombe.Svg:
the golden report, each refusal, and the quartet's can-fail arm. -/
open Anscombe

def golden : String :=
  "set I: n=11 mean_x=9.00 mean_y=7.50 slope=0.50 " ++
  "intercept=3.00 r=0.82\n" ++
  "set II: n=11 mean_x=9.00 mean_y=7.50 slope=0.50 " ++
  "intercept=3.00 r=0.82\n" ++
  "set III: n=11 mean_x=9.00 mean_y=7.50 slope=0.50 " ++
  "intercept=3.00 r=0.82\n" ++
  "set IV: n=11 mean_x=9.00 mean_y=7.50 slope=0.50 " ++
  "intercept=3.00 r=0.82\n"

def count (s sub : String) : Nat := (s.splitOn sub).length - 1

def isErr {α : Type} (e : Except String α) (want : String) : Bool :=
  match e with
  | .error m => m == want
  | .ok _ => false

def main : IO UInt32 := do
  let root := (← IO.getEnv "ADS_ROOT").getD "../.."
  let csv ← IO.FS.readFile s!"{root}/data/anscombe/anscombe.csv"
  let mut bad : List String := []
  let chk := fun (name : String) (ok : Bool) (b : List String) =>
    if ok then b else b ++ [name]
  -- parseDec
  bad := chk "dec 8.04" (parseDec "8.04" == some 8.04) bad
  bad := chk "dec 10" (parseDec "10" == some 10.0) bad
  bad := chk "dec empty" (parseDec "" == none) bad
  bad := chk "dec trailing point" (parseDec "1." == none) bad
  bad := chk "dec letters" (parseDec "a" == none) bad
  bad := chk "dec two points" (parseDec "1.2.3" == none) bad
  bad := chk "dec leading point" (parseDec ".5" == none) bad
  bad := chk "dec bad frac" (parseDec "1.x" == none) bad
  -- fmt2
  bad := chk "fmt2 half" (fmt2 0.5 == "0.50") bad
  bad := chk "fmt2 neg" (fmt2 (-1.234) == "-1.23") bad
  bad := chk "fmt2 int" (fmt2 9 == "9.00") bad
  bad := chk "fmt2 pad" (fmt2 0.05 == "0.05") bad
  -- parse
  let sets ← IO.ofExcept (parse csv)
  bad := chk "four sets" (sets.map (·.1) == names) bad
  bad := chk "eleven each" (sets.all (·.2.length == 11)) bad
  bad := chk "first point"
    (sets.headD ("", []) |>.2.headD (0, 0) == (10, 8.04)) bad
  bad := chk "header only"
    ((parse "set,x,y\n").toOption.map (·.all (·.2.isEmpty))
      == some true) bad
  bad := chk "fields" (isErr (parse "h\nI,1\n") "line 2: want 3 fields") bad
  bad := chk "bad x" (isErr (parse "h\nI,a,1\n") "line 2: bad x") bad
  bad := chk "bad y" (isErr (parse "h\nI,1,b\n") "line 2: bad y") bad
  bad := chk "unknown set"
    (isErr (parse "h\nV,1,2\n") "line 2: unknown set V") bad
  -- stats and report
  let (mx, my, b, a, r) := stats [(0, 1), (1, 3), (2, 5)]
  bad := chk "stats line" (mx == 1 && my == 3 && b == 2 && a == 1 && r == 1) bad
  bad := chk "golden report" (report sets == golden) bad
  bad := chk "tail" (tail "set I: n=1 mean_x=9.00" == "9.00") bad
  bad := chk "tail missing" (tail "nothing" == "") bad
  bad := chk "agree" (agree golden) bad
  -- the can-fail arm: one changed value breaks the agreement
  let mut mutant : Sets := sets
  mutant := mutant.map fun (k, p) =>
    if k == "IV" then (k, p.map fun q => (q.1, q.2 + 1)) else (k, p)
  bad := chk "mutant disagrees" (!(agree (report mutant))) bad
  bad := chk "agree needs four" (!(agree "set I: mean_x=1\n")) bad
  -- svg
  let svg ← IO.ofExcept (plotSvg sets)
  bad := chk "svg head" (svg.startsWith "<svg xmlns=") bad
  bad := chk "svg tail" (svg.endsWith "</svg>\n") bad
  bad := chk "svg captions"
    (count svg "text-anchor=\"middle\">Set " == 4) bad
  bad := chk "svg circles" (count svg "<circle" == 44) bad
  bad := chk "svg fit lines" (count svg "<line " == 4) bad
  bad := chk "svg no nan" (count svg "NaN" == 0 && count svg "inf" == 0) bad
  bad := chk "svg deterministic"
    ((plotSvg sets).toOption == some svg) bad
  bad := chk "svg refuses three"
    (isErr (plotSvg (sets.take 3)) "want four sets") bad
  if bad.isEmpty then
    IO.println "contract: ads-lean-anscombe-test-v1 OK"
    return 0
  IO.eprintln s!"FAIL {bad}"
  return 1
