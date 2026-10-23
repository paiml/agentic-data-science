import AgenticDS
import Lean.Data.Json

open AgenticDS Lean

def jnum (j : Json) : Option ℚ :=
  match j.getNum? with
  | .ok d => some ((d.mantissa : ℚ) / (10 ^ d.exponent : ℕ))
  | .error _ => none

def absLt (a b tol : ℚ) : Bool := (if a < b then b - a else a - b) < tol

/-- `x` is within `tol` of `sqrt m` (stated on squares: |x² - m| < 2 x tol). -/
def sqrtClose (m x tol : ℚ) : Bool := absLt (x * x) m (2 * x * tol)

def check (what : String) (ok : Bool) : IO Bool := do
  unless ok do IO.eprintln s!"FAIL {what}"
  pure ok

def main (args : List String) : IO UInt32 := do
  let root := args.headD "../.."
  let red ← IO.FS.readFile s!"{root}/datasets/wine-quality/winequality-red.csv"
  let white ← IO.FS.readFile s!"{root}/datasets/wine-quality/winequality-white.csv"
  let golden ← IO.FS.readFile s!"{root}/datasets/golden/p4.json"
  let some g := (Json.parse golden).toOption | IO.eprintln "FAIL golden parse"; return 1
  let get (path : List String) : Option ℚ :=
    (path.foldl (fun j k => j.bind (fun j => (j.getObjVal? k).toOption)) (some g)).bind jnum
  let raw := readWine red ++ readWine white
  let rows := clean raw
  let train := trainRows rows
  let test := testRows rows
  let β := fitCoefs train
  let sse := sseRows β test
  let n : ℚ := test.length
  let mean (c : Bool) : ℚ :=
    let q := (rows.filter (·.white == c)).map (·.quality)
    q.sum / (q.length : ℚ)
  let mut ok ← check "all rows valid (nothing dropped)" (raw.length == 6497 && rows.length == 6497)
  ok := (← check "n_train" ((get ["n_train"]).any (· == (train.length : ℚ)))) && ok
  ok := (← check "n_test" ((get ["n_test"]).any (· == (test.length : ℚ)))) && ok
  ok := (← check "rmse" ((get ["rmse"]).any (sqrtClose (sse / n) · (1 / 1000000)))) && ok
  ok := (← check "r2" ((get ["r2"]).any (absLt (1 - sse / sstRows test) · (1 / 1000000)))) && ok
  ok := (← check "mean red" ((get ["mean_quality_by_color", "red"]).any (absLt (mean false) · (1 / 1000000000)))) && ok
  ok := (← check "mean white" ((get ["mean_quality_by_color", "white"]).any (absLt (mean true) · (1 / 1000000000)))) && ok
  -- validation refuses bad rows: a missing feature, quality 11, and an unknown colour
  let bad : List WineRaw :=
    [⟨(List.replicate 11 (some 1)).set 3 none, some 5, "red"⟩, ⟨List.replicate 11 (some 1), some 11, "red"⟩,
     ⟨List.replicate 11 (some 1), some 5, "rose"⟩, ⟨List.replicate 11 (some 1), some 5, "white"⟩]
  ok := (← check "validation refuses 3 of 4" ((clean bad).length == 1)) && ok
  ok := (← check "train + test = n" (train.length + test.length == rows.length)) && ok
  if ok then IO.println "contract: ads-lean-p4-v1 OK"; return 0
  else return 1
