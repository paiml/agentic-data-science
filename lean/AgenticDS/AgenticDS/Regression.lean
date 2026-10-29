import AgenticDS.Ols
import AgenticDS.Profile

namespace AgenticDS

/-- Fitted line value at `x`. -/
def predict (a b x : ℚ) : ℚ := a + b * x

/-- (flipper_length_mm, body_mass_g) pairs of the complete rows. -/
def flipperMass (txt : String) : List (ℚ × ℚ) :=
  (completeRows txt).filterMap (fun r => match r.2[2]?, r.2[3]? with
    | some x, some y => some (x, y)
    | _, _ => none)

/-- Sum of squared residuals of the line `a + b x` over `d`. -/
def sse (a b : ℚ) (d : List (ℚ × ℚ)) : ℚ := (d.map fun p => (p.2 - predict a b p.1) ^ 2).sum

/-- Total sum of squares around the mean of y. -/
def sst (d : List (ℚ × ℚ)) : ℚ :=
  let m := (d.map Prod.snd).sum / (d.length : ℚ)
  (d.map fun p => (p.2 - m) ^ 2).sum

def r2 (d : List (ℚ × ℚ)) : ℚ :=
  1 - sse (olsIntercept d) (olsSlope d) d / sst d

/-- Mean squared error of the fitted line (RMSE is its square root). -/
def mse (d : List (ℚ × ℚ)) : ℚ := sse (olsIntercept d) (olsSlope d) d / (d.length : ℚ)

/-- Fold ids from `folds.csv` (header dropped), one per complete row. -/
def readFolds (txt : String) : List Nat :=
  (parseCsv txt).drop 1 |>.filterMap (fun f => f[1]?.bind String.toNat?)

/-- Pooled out-of-fold mean squared error: train on the other folds, predict the held-out fold. -/
def cvMse (d : List (ℚ × ℚ)) (folds : List Nat) (k : Nat) : ℚ :=
  let tagged := d.zip folds
  let errs := (List.range k).flatMap fun f =>
    let train := (tagged.filter (·.2 ≠ f + 1)).map Prod.fst
    let test := (tagged.filter (·.2 = f + 1)).map Prod.fst
    let a := olsIntercept train
    let b := olsSlope train
    test.map fun p => (p.2 - predict a b p.1) ^ 2
  errs.sum / (errs.length : ℚ)

end AgenticDS
