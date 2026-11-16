/-
Copyright (c) 2026 Pragmatic AI Labs. All rights reserved.
Released under MIT license as described in the file LICENSE.
Authors: Pragmatic AI Labs
-/
import AgenticDS.Plot
import AgenticDS.Profile
import Lean.Data.Json

/-! # Real data the module 1 demos plot

The penguins rows, the golden means and a source scanner. The
scanner builds each banned word from two pieces, so this file
never holds one whole. -/

namespace AgenticDS

/-- Complete penguin rows: species, then bill length, bill depth,
flipper length and body mass. -/
def m1Rows : IO (List (String × List ℚ)) := do
  pure (completeRows (← IO.FS.readFile
    "../../datasets/penguins/penguins.csv"))

/-- A JSON number as an exact rational. -/
def jsonQ (d : Lean.JsonNumber) : ℚ :=
  (d.mantissa : ℚ) / (10 ^ d.exponent : ℕ)

/-- The golden mean of column `c` for species `sp`. -/
def goldMean (j : Lean.Json) (sp c : String) : Option ℚ :=
  (j.getObjValD "species" |>.getObjValD sp |>.getObjValD c
    |>.getObjValD "mean" |>.getNum?.toOption).map jsonQ

/-- The `.lean` files of a directory, sorted by name. -/
def leanFiles (dir : System.FilePath) :
    IO (List System.FilePath) := do
  let es ← dir.readDir
  let ps := es.map (·.path)
  pure ((ps.qsort fun a b => a.toString < b.toString).toList.filter
    fun p => p.extension == some "lean")

/-- Lines in a text. -/
def nLines (t : String) : Nat := (t.splitOn "\n").length - 1

/-- The words the gate scan refuses, each built from two pieces. -/
def banned : List String :=
  ["so" ++ "rry", "ad" ++ "mit", "native_" ++ "decide",
   "TO" ++ "DO", "FIX" ++ "ME", "HA" ++ "CK", "XX" ++ "X"]

/-- Occurrences of every banned word in a text. -/
def hits (t : String) : Nat :=
  (banned.map fun w => (t.splitOn w).length - 1).sum

end AgenticDS
