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
  let csv ← IO.FS.readFile s!"{root}/datasets/penguins/penguins.csv"
  let foldsTxt ← IO.FS.readFile s!"{root}/datasets/fixtures/folds.csv"
  let golden ← IO.FS.readFile s!"{root}/datasets/golden/p2.json"
  let some g := (Json.parse golden).toOption | IO.eprintln "FAIL golden parse"; return 1
  let get (path : List String) : Option ℚ :=
    (path.foldl (fun j k => j.bind (fun j => (j.getObjVal? k).toOption)) (some g)).bind jnum
  let d := flipperMass csv
  let folds := readFolds foldsTxt
  let a := olsIntercept d
  let b := olsSlope d
  let mut ok ← check "342 pairs" (d.length == 342)
  ok := (← check "342 folds" (folds.length == 342)) && ok
  ok := (← check "slope" ((get ["ols", "slope"]).any (absLt b · (1 / 100000000)))) && ok
  ok := (← check "intercept" ((get ["ols", "intercept"]).any (absLt a · (1 / 100000000)))) && ok
  ok := (← check "r2" ((get ["metrics", "ols", "r2"]).any (absLt (r2 d) · (1 / 1000000000)))) && ok
  ok := (← check "rmse" ((get ["metrics", "ols", "rmse"]).any (sqrtClose (mse d) · (1 / 1000000)))) && ok
  ok := (← check "cv rmse" ((get ["cv_rmse", "ols"]).any (sqrtClose (cvMse d folds 5) · (1 / 1000000)))) && ok
  -- exact normal equations on the real data: residuals sum to zero, x-weighted residuals sum to zero
  ok := (← check "residuals sum 0" ((d.map fun p => p.2 - a - b * p.1).sum == 0)) && ok
  ok := (← check "x-residuals sum 0" ((d.map fun p => p.1 * (p.2 - a - b * p.1)).sum == 0)) && ok
  if ok then IO.println "contract: ads-lean-p2-v1 OK"; return 0
  else return 1
