import AgenticDS.P4

/-! P4 golden test: Lean pipeline against the R golden file. -/

open AgenticDS Lean

-- Exact value of a JSON number (mantissa / 10 ^ exponent).
def num : Json → ℚ
  | .num n => n.mantissa / (10 ^ n.exponent : ℕ)
  | _ => 0

def near (a b tol : ℚ) : Bool :=
  (if a < b then b - a else a - b) ≤ tol

-- sqrt mse is within tol of rmse (squares compare exactly).
def nearSqrt (mse rmse tol : ℚ) : Bool :=
  (rmse - tol) ^ 2 ≤ mse && mse ≤ (rmse + tol) ^ 2

def main (args : List String) : IO UInt32 := do
  let root := args.headD "../.."
  let txt ← IO.FS.readFile s!"{root}/datasets/golden/p4.json"
  let g ← IO.ofExcept (Json.parse txt)
  let c := g.getObjValD "mean_quality_by_color"
  let some r ← p4Run root | IO.eprintln "FAIL fit"; pure 1
  let n := fun k => num (g.getObjValD k)
  let checks : List (String × Bool) := [
    ("n_rows", r.nRows == n "n_rows"),
    ("n_train", r.nTrain == n "n_train"),
    ("n_test", r.nTest == n "n_test"),
    ("rmse", nearSqrt r.mse (n "rmse") (1/1000000)),
    ("r2", near r.r2 (n "r2") (1/1000000)),
    ("red", near r.red (num (c.getObjValD "red"))
      (1/1000000000)),
    ("white", near r.white (num (c.getObjValD "white"))
      (1/1000000000))]
  let mut ok := true
  for (what, good) in checks do
    unless good do IO.eprintln s!"FAIL {what}"; ok := false
  if ok then IO.println "contract: ads-lean-p4-v1 OK"
  pure (if ok then 0 else 1)
