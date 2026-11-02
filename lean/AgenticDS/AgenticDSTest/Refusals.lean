/-
Copyright (c) 2026 Pragmatic AI Labs. All rights reserved.
Released under MIT license as described in the file LICENSE.
Authors: Pragmatic AI Labs
-/
import AgenticDS.Csv
import AgenticDS.Cv
import AgenticDS.Ols
import AgenticDS.Pipeline
import AgenticDS.Plot
import AgenticDS.Tree
import AgenticDS.Examples.Run

/-! # Refusal paths and small helpers

Lean has no line-coverage tool, so the fn-coverage check
(`scripts/check-lean-fn-coverage.sh`) requires every
refusal path (`none` or `throw`) to carry a test.
Each check below is named `refusal <Module>.<def> <kind>`, and that
name is the label in `scripts/refusals.tsv`. -/

open AgenticDS

def check (what : String) (ok : Bool) : IO Bool := do
  unless ok do IO.eprintln s!"FAIL {what}"
  pure ok

def raw (fs : List (Option ℚ)) (q : Option ℚ) (c : String) :
    WineRaw :=
  ⟨fs, q, c⟩

def elevenOnes : List (Option ℚ) := List.replicate 11 (some 1)

/-- True when `act` fails with exactly the message `msg`. -/
def refuses {α : Type} (act : IO α) (msg : String) : IO Bool := do
  try
    let _ ← act
    pure false
  catch e => pure (toString e == msg)

def main (args : List String) : IO UInt32 := do
  let root := args.headD "../.."
  let csv ← readCsv root
  let r1 ← refuses (refuseUnless false "boom") "boom"
  let r2 ← refuses (refuseUnless true "boom") "boom"
  let r3 ← refuses (orRefuse (none : Option Nat) "none") "none"
  let r4 ← orRefuse (some 3) "none"
  let r5 ← refuses (contract "x" false) "contract x violated"
  let rows : List Row := [⟨[0], .adelie⟩, ⟨[1], .gentoo⟩]
  let checks : List (String × Bool) := [
    ("refusal Csv.parseRat none: a letter after the point",
      (parseRat "1.x").isNone),
    ("refusal Csv.parseRat none: two points",
      (parseRat "1.2.3").isNone),
    ("refusal Csv.parseRat none: not a number",
      (parseRat "abc").isNone),
    ("Csv.parseRat accepts 38.7",
      parseRat "38.7" == some (387 / 10)),
    ("refusal Csv.toRawRow none: a short row",
      (toRawRow ["Adelie", "Torgersen", "39.1"]).isNone),
    ("Csv.toRawRow marks NA as none",
      (toRawRow ["A", "T", "NA", "1", "2", "3"]).map (·.measures)
        == some [none, some 1, some 2, some 3]),
    ("Ols.pairsOf: unknown column gives no pairs",
      (pairsOf csv "no_such" "body_mass_g").isEmpty),
    ("Ols.pairsOf: a row with NA is dropped",
      (pairsOf "a,b\n1,NA\n2,3\n" "a" "b") == [(2, 3)]),
    ("refusal Pipeline.validate none: wrong feature count",
      (validate (raw [some 1] (some 5) "red")).isNone),
    ("refusal Pipeline.validate none: a missing feature",
      (validate
        (raw (none :: elevenOnes.tail!) (some 5) "red")).isNone),
    ("refusal Pipeline.validate none: quality above 10",
      (validate (raw elevenOnes (some 11) "red")).isNone),
    ("refusal Pipeline.validate none: quality below 0",
      (validate (raw elevenOnes (some (-1)) "red")).isNone),
    ("refusal Pipeline.validate none: unknown colour",
      (validate (raw elevenOnes (some 5) "rose")).isNone),
    ("Pipeline.validate accepts a good white row",
      (validate (raw elevenOnes (some 5) "white")).map (·.white)
        == some true),
    ("refusal Pipeline.gaussSolve none: singular matrix",
      (gaussSolve [[1, 2], [2, 4]] [1, 2]).isNone),
    ("Pipeline.gaussSolve solves x + y = 3, x - y = 1",
      gaussSolve [[1, 1], [1, -1]] [3, 1] == some [2, 1]),
    ("refusal Examples.Run.refuseUnless throw: a false guard",
      r1),
    ("Examples.Run.refuseUnless lets a true guard pass", !r2),
    ("refusal Examples.Run.orRefuse throw: no value", r3),
    ("Examples.Run.orRefuse returns the value", r4 == 3),
    ("Examples.Run.contract refuses a false contract", r5),
    ("refusal Tree.bestSplit none: no rows",
      (bestSplit 1 []).isNone),
    ("refusal Tree.bestSplit none: min rows too big",
      (bestSplit 2 rows).isNone),
    ("Tree.bestSplit splits two classes",
      (bestSplit 1 rows).isSome),
    ("Plot.qf converts 3/2 to 1.5",
      qf (3 / 2) == 1.5)]
  let mut ok := true
  let mut passed := 0
  for (w, b) in checks do
    if ← check w b then passed := passed + 1 else ok := false
  IO.println s!"{passed}/{checks.length} refusal checks"
  if ok then
    assert! passed == checks.length
    IO.println "contract: ads-lean-refusals-v1 OK"
    pure 0
  else pure 1
