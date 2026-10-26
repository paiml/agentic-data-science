import AgenticDS.Examples.M2
import AgenticDS.Cv
import AgenticDS.Examples.Run

/-! Module 2 example checks: registry, every example runs,
and the exact values each example states. -/

open AgenticDS

-- Compile-time facts: the 3-point guard data of example 9.
def tri : Data ℚ := [(1, 2), (2, 4), (3, 7)]
#guard sx tri == 6 && sy tri == 13 && sxx tri == 14
#guard sxy tri == 31 && cnt tri == 3
#guard olsSlope tri == 5 / 2
#guard olsIntercept tri == -2 / 3
#guard olsSlope ([(1, 2), (2, 4), (3, 6)] : Data ℚ) == 2
#guard (resid tri (olsIntercept tri) (olsSlope tri)).sum == 0
#guard (residX tri (olsIntercept tri) (olsSlope tri)).sum == 0
#guard (resid tri 1 2).sum == sy tri - cnt tri * 1 - 2 * sx tri

def has (o s : String) : Bool := (o.splitOn s).length > 1

def lines (path : String) : IO (List String) := do
  let t ← IO.FS.readFile path
  let ls := t.splitOn "\n"
  pure (if ls.getLast? == some "" then ls.dropLast else ls)

def main (_ : List String) : IO UInt32 := do
  let dir : System.FilePath := "AgenticDS/Examples"
  let files := ((← dir.readDir).filter
    fun e => e.fileName.startsWith "M2V").size
  let mut ok := true
  let fail (m : String) : IO Unit := IO.eprintln s!"FAIL {m}"
  if files != examplesM2.length then
    fail s!"{files} files, {examplesM2.length} examples"
    ok := false
  let ids := (List.range 10).map fun i =>
    s!"v{if i + 1 < 10 then "0" else ""}{i + 1}"
  if examplesM2.map (·.1) != ids then
    fail s!"ids {examplesM2.map (·.1)}"
    ok := false
  -- v09: the true guard and the planted wrong one exist.
  let good ← IO.FS.readFile "AgenticDS/Examples/M2V09.lean"
  let bad ← IO.FS.readFile "AgenticDSTest/PlantedWrongSlope.lean"
  unless has good "#guard olsSlope m2v09_data == 5 / 2" &&
      has bad "#guard olsSlope planted == 2" do
    fail "v09 guard files"; ok := false
  let mut outs : List (String × String) := []
  for (id, act) in examplesM2 do
    try
      let (o, _) ← IO.FS.withIsolatedStreams act
      outs := outs ++ [(id, o)]
    catch e => fail s!"{id}: {e}"; ok := false
  let out (id : String) := (outs.lookup id).getD ""
  let root := "../.."
  let csv ← IO.FS.readFile s!"{root}/datasets/penguins/penguins.csv"
  let d := flipperMass csv
  let folds ← readFolds root
  let rmse := cvRmse d folds 5
  let reg ← lines "AgenticDS/Regression.lean"
  let regT := "\n".intercalate reg
  let gold ← IO.FS.readFile s!"{root}/datasets/golden/p2.json"
  let m4 ← lines "AgenticDS/Examples/M2V04.lean"
  let m5 ← lines "AgenticDS/Examples/M2V05.lean"
  let sig := "(hden : cnt d * sxx d - sx d ^ 2 ≠ 0)"
  let checks : List (String × Bool) := [
    ("v01 head shows field K and the five sums",
      has regT "variable {K : Type*} [Field K]" &&
        has regT "def sx " && has regT "def sy " &&
        has regT "def sxx " && has regT "def sxy " &&
        has regT "def cnt "),
    ("v02 sums and the two ols defs exist",
      has regT "def olsSlope" && has regT "def olsIntercept" &&
        has regT "(cnt d * sxy d - sx d * sy d)"),
    ("v03 theorem, hn, hden and both lemmas exist",
      has regT "theorem ols_normal_equations" &&
        has regT "(hn : cnt d ≠ 0)" && has regT sig &&
        has regT "theorem resid_sum" &&
        has regT "theorem resid_x_sum"),
    ("v03 exact residual sums are 0 on penguins",
      (resid d (olsIntercept d) (olsSlope d)).sum == 0 &&
        (residX d (olsIntercept d) (olsSlope d)).sum == 0),
    ("v04 the file Lean runs has trace_state and #check",
      m4.any (has · "trace_state") &&
        m4.any (has · "#check @ols_normal_equations")),
    ("v05 the file Lean runs has the real-number #check",
      m5.any (has · "#check @ols_residuals_sum_zero_real") &&
        has regT "theorem ols_residuals_sum_zero_real"),
    ("v05 proof is the one-liner first half",
      reg.any (has · "(ols_normal_equations d hn hden).1")),
    ("v06 exact slope", olsSlope d == 1145743050 / 23059877),
    ("v06 exact intercept",
      olsIntercept d == -133305260075 / 23059877),
    ("v06 printed both fractions",
      has (out "v06") "slope: 1145743050/23059877" &&
        has (out "v06") "intercept: -133305260075/23059877"),
    ("v06 near the golden (tol 1e-9)",
      let q := olsIntercept d + 578083135807716 / 100000000000
      let r := olsSlope d - 496855664061006 / 10000000000000
      (if q < 0 then -q else q) ≤ 1 / 1000000000 &&
        (if r < 0 then -r else r) ≤ 1 / 1000000000),
    ("v06 golden file holds both numbers",
      has gold "\"intercept\": -5780.83135807716" &&
        has gold "\"slope\": 49.6855664061006"),
    ("v08 342 fold ids in 1..5",
      folds.length == 342 && folds.all fun f => 1 ≤ f && f ≤ 5),
    ("v08 cv rmse is 394.312960",
      (toString rmse).startsWith "394.312960" &&
        has (out "v08") "cv rmse: 394.312960"),
    ("v08 agrees with golden 394.312960342554",
      (Float.abs (rmse - 394.312960342554)) < 1e-6 &&
        has gold "\"ols\": 394.312960342554")]
  let mut passed := 0
  for (what, good) in checks do
    if good then passed := passed + 1
    else fail what; ok := false
  IO.eprintln s!"{passed}/{checks.length} example checks"
  if ok then IO.println "contract: ads-lean-examples-m2-v1 OK"
  pure (if ok then 0 else 1)
