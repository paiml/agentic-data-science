import AgenticDS.Profile
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
  if |m - g| < 1 / 1000000000 then
    IO.println "contract: ads-lean-p1-v1 OK"
  else throw (IO.userError "FAIL parity")
