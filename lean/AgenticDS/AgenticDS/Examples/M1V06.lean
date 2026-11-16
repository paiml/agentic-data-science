import AgenticDS.Examples.Run
import AgenticDS.Examples.M1Data
/-! Golden parity against R, compared exactly in ℚ. -/
open AgenticDS Lean

-- Golden Adelie body mass mean from R, exactly (ℚ).
def m1v06_gold (j : Json) : Option ℚ :=
  (j.getObjValD "species" |>.getObjValD "Adelie"
    |>.getObjValD "body_mass_g" |>.getObjValD "mean"
    |>.getNum?.toOption).map
    fun d => (d.mantissa : ℚ) / (10 ^ d.exponent : ℕ)

def m1v06 : IO Unit := do
  let rows := completeRows (← IO.FS.readFile
    "../../datasets/penguins/penguins.csv")
  let m := mean (column rows "Adelie" 3)
  let j ← IO.ofExcept (Json.parse (← IO.FS.readFile
    "../../datasets/golden/p1.json"))
  let g := (m1v06_gold j).getD 0
  IO.println s!"mean {Rat.toFloat m} gold {Rat.toFloat g}"
  refuseUnless (|m - g| < 1 / 1000000000) "FAIL parity"
  IO.println "contract: ads-lean-p1-v1 OK"
  -- All twelve species-by-column means against the golden R means.
  let cols := ["bill_length_mm", "bill_depth_mm",
    "flipper_length_mm", "body_mass_g"]
  let mut pts : List (Float × Float) := []
  let mut worst : ℚ := 0
  for sp in ["Adelie", "Chinstrap", "Gentoo"] do
    for (c, k) in cols.zipIdx do
      let a := mean (column rows sp k)
      let b ← orRefuse (goldMean j sp c) s!"no gold for {sp} {c}"
      pts := pts ++ [(qf b, qf a)]
      worst := max worst |a - b|
  IO.println s!"{pts.length} means, worst gap {Rat.toFloat worst}"
  refuseUnless (worst < 1 / 1000000000) "FAIL parity on all means"
  IO.println "all 12 means agree with R"
  writeScatterDerived
    "plot-m1v06.svg" "Lean mean against R golden mean"
    "golden mean from R (mm or g)" "mean computed in Lean" pts
    [(18, 18), (5100, 5100)] []
    [s!"{pts.length} means", "line: exact agreement"]
