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

/-- A pure check as an action. -/
def t (b : Bool) : IO Bool := pure b

def main (args : List String) : IO UInt32 := do
  let root := args.headD "../.."
  let csv ← readCsv root
  let rows : List Row := [⟨[0], .adelie⟩, ⟨[1], .gentoo⟩]
  let checks : List (String × IO Bool) := [
    ("refusal Csv.parseRat none: a letter after the point",
      t (parseRat "1.x").isNone),
    ("refusal Csv.parseRat none: two points",
      t (parseRat "1.2.3").isNone),
    ("refusal Csv.parseRat none: not a number",
      t (parseRat "abc").isNone),
    ("Csv.parseRat accepts 38.7",
      t (parseRat "38.7" == some (387 / 10))),
    ("refusal Csv.toRawRow none: a short row",
      t (toRawRow ["Adelie", "Torgersen", "39.1"]).isNone),
    ("Csv.toRawRow marks NA as none",
      t ((toRawRow ["A", "T", "NA", "1", "2", "3"]).map
        (·.measures) == some [none, some 1, some 2, some 3])),
    ("Ols.pairsOf: unknown column gives no pairs",
      t (pairsOf csv "no_such" "body_mass_g").isEmpty),
    ("Ols.pairsOf: a row with NA is dropped",
      t (pairsOf "a,b\n1,NA\n2,3\n" "a" "b" == [(2, 3)])),
    ("refusal Pipeline.validate none: wrong feature count",
      t (validate (raw [some 1] (some 5) "red")).isNone),
    ("refusal Pipeline.validate none: a missing feature",
      t (validate
        (raw (none :: elevenOnes.tail!) (some 5) "red")).isNone),
    ("refusal Pipeline.validate none: quality above 10",
      t (validate (raw elevenOnes (some 11) "red")).isNone),
    ("refusal Pipeline.validate none: quality below 0",
      t (validate (raw elevenOnes (some (-1)) "red")).isNone),
    ("refusal Pipeline.validate none: unknown colour",
      t (validate (raw elevenOnes (some 5) "rose")).isNone),
    ("Pipeline.validate accepts a good white row",
      t ((validate (raw elevenOnes (some 5) "white")).map
        (·.white) == some true)),
    ("refusal Pipeline.gaussSolve none: singular matrix",
      t (gaussSolve [[1, 2], [2, 4]] [1, 2]).isNone),
    ("Pipeline.gaussSolve solves x + y = 3, x - y = 1",
      t (gaussSolve [[1, 1], [1, -1]] [3, 1] == some [2, 1])),
    ("refusal Examples.Run.refuseUnless throw: a false guard",
      refuses (refuseUnless false "boom") "boom"),
    ("Examples.Run.refuseUnless lets a true guard pass",
      do pure !(← refuses (refuseUnless true "boom") "boom")),
    ("refusal Examples.Run.orRefuse throw: no value",
      refuses (orRefuse (none : Option Nat) "none") "none"),
    ("Examples.Run.orRefuse returns the value",
      do pure ((← orRefuse (some 3) "none") == 3)),
    ("Examples.Run.contract refuses a false contract",
      refuses (contract "x" false) "contract x violated"),
    ("refusal Tree.bestSplit none: no rows",
      t (bestSplit 1 []).isNone),
    ("refusal Tree.bestSplit none: min rows too big",
      t (bestSplit 2 rows).isNone),
    ("Tree.bestSplit splits two classes",
      t (bestSplit 1 rows).isSome),
    ("Plot.qf converts 3/2 to 1.5",
      t (qf (3 / 2) == 1.5))]
  let mut ok := true
  let mut passed := 0
  for (w, act) in checks do
    if ← check w (← act) then
      passed := passed + 1
      IO.println s!"ok {w}"
    else ok := false
  IO.println s!"{passed}/{checks.length} refusal checks"
  if ok then
    assert! passed == checks.length
    IO.println "contract: ads-lean-refusals-v1 OK"
    pure 0
  else pure 1
