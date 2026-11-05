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
  let bad ← IO.FS.readFile
    "AgenticDSTest/PlantedWrongSlope.lean.planted"
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
  -- Every id's plot: printed line, contract line, and the
  -- written SVG holds one circle per point and mark.
  let plots : List (String × Nat × Nat) :=
    [("v01", 342, 0), ("v02", 342, 0), ("v03", 3, 0),
     ("v04", 7, 1), ("v05", 342, 0), ("v06", 342, 0),
     ("v07", 342, 0), ("v08", 342, 0), ("v09", 342, 0),
     ("v10", 342, 1)]
  let mut plotChecks : List (String × Bool) := []
  for (id, n, m) in plots do
    let f := s!"plot-m2{id}.svg"
    let svg ← IO.FS.readFile f
    plotChecks := plotChecks ++ [
      (s!"{id} prints its plot line",
        has (out id) s!"svg {n} points {f}"),
      (s!"{id} contract plot_scatter_bounded",
        has (out id) "contract: plot_scatter_bounded OK"),
      (s!"{id} svg has {n + m} circles and closes",
        (svg.splitOn "<circle").length - 1 == n + m &&
          has svg "</svg>" && has svg "<polyline")]
  let checks : List (String × Bool) := plotChecks ++ [
    ("v01 the five sums",
      has (out "v01") "cnt 342, sx 68713, sy 1437000" &&
        has (out "v01") "sxx 13872913, sxy 292065275"),
    ("v02 bill length sums and slope",
      has (out "v02") "cnt 342, sx 150213/10, sy 1437000" &&
        has (out "v02") "slope: 3376326000/38623981"),
    ("v04 residual sum is 0 at the fitted intercept",
      has (out "v04") "sum at fitted intercept: 0" &&
        has (out "v04") "identity holds: true"),
    ("v05 residuals sum to 0",
      has (out "v05") "residuals sum: 0"),
    ("v06 on-screen text plot, 342 points, contract",
      has (out "v06") "text plot 342 points" &&
        has (out "v06") "contract: plot_text_scatter_bounded OK" &&
        has (out "v06") "●" && has (out "v06") "·"),
    ("v07 bill against flipper slope",
      has (out "v07") "slope 195830750/115871943"),
    ("v09 true slope passes, planted 2 does not",
      has (out "v09") "guard true slope: true" &&
        has (out "v09") "guard planted slope 2: false"),
    ("v10 the line passes through the means",
      has (out "v10") "mean x 58657/3420, mean y 239500/57" &&
        has (out "v10") "line passes the means: true"),
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
