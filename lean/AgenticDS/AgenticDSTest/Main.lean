import AgenticDS
import Lean.Data.Json
/-! Golden parity: Lean statistics match the pinned values. -/


open AgenticDS Lean

/-- Exact decimal text of a JSON number as a rational. -/
def jnum (j : Json) : Option ℚ :=
  match j.getNum? with
  | .ok d => some ((d.mantissa : ℚ) / (10 ^ d.exponent : ℕ))
  | .error _ => none

def absDiff (a b : ℚ) : ℚ := if a < b then b - a else a - b

def close (a b : ℚ) : Bool := absDiff a b < 1 / 1000000000

def check (what : String) (ok : Bool) : IO Bool := do
  unless ok do IO.eprintln s!"FAIL {what}"
  pure ok

def main (args : List String) : IO UInt32 := do
  let root := args.headD "../.."
  let csv ← IO.FS.readFile s!"{root}/datasets/penguins/penguins.csv"
  let golden ← IO.FS.readFile s!"{root}/datasets/golden/p1.json"
  let some g := (Json.parse golden).toOption
    | IO.eprintln "FAIL golden parse"; return 1
  let rows := completeRows csv
  let mut ok ← check "342 complete rows" (rows.length == 342)
  let cols := ["bill_length_mm", "bill_depth_mm",
    "flipper_length_mm", "body_mass_g"]
  for sp in ["Adelie", "Chinstrap", "Gentoo"] do
    let some gs :=
        (g.getObjVal? "species" >>= (·.getObjVal? sp)).toOption
      | IO.eprintln s!"FAIL golden species {sp}"; return 1
    let n := (column rows sp 0).length
    let gn := (gs.getObjValAs? Nat "n").toOption.getD 0
    ok := (← check s!"{sp} n" (n == gn)) && ok
    for (c, i) in cols.zip [0, 1, 2, 3] do
      let some gc := (gs.getObjVal? c).toOption
        | IO.eprintln s!"FAIL golden {sp}.{c}"; return 1
      let xs := column rows sp i
      let gm := (gc.getObjVal? "mean").toOption.bind jnum
      let gsd := (gc.getObjVal? "sd").toOption.bind jnum
      ok := (← check s!"{sp}.{c} mean"
        (gm.any (close (mean xs)))) && ok
      -- sd² vs sample variance (golden sd has 15 significant
      -- digits), abs tol 1e-9
      ok := (← check s!"{sp}.{c} sd" (gsd.any (fun s =>
        close (s * s) (sampleVariance xs)))) && ok
  if ok then IO.println "contract: ads-lean-p1-v1 OK"; return 0
  else return 1
