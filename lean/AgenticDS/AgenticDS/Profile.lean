/-
Copyright (c) 2026 Pragmatic AI Labs. All rights reserved.
Released under MIT license as described in the file LICENSE.
Authors: Pragmatic AI Labs
-/
import AgenticDS.Csv
import AgenticDS.Stats

/-! # Missing-value policy, columns and sample variance -/

namespace AgenticDS

/-- Missing-value policy: keep a row only when all four numeric
measurements are present. -/
def completeRow (r : RawRow) : Option (String × List ℚ) :=
  (r.measures.mapM id).map (fun v => (r.species, v))

/-- Complete rows of a CSV body (header dropped). -/
def completeRows (txt : String) : List (String × List ℚ) :=
  (parseCsv txt).drop 1
    |>.filterMap (fun f => (toRawRow f).bind completeRow)

/-- Values of numeric column `c` for one species. -/
def column (rows : List (String × List ℚ)) (sp : String)
    (c : Nat) : List ℚ :=
  (rows.filter (·.1 = sp)).filterMap (fun r => r.2[c]?)

/-- Sample variance (n - 1 denominator), matching R's `var`. -/
def sampleVariance (xs : List ℚ) : ℚ :=
  (xs.map (fun x => (x - mean xs) ^ 2)).sum / ((xs.length : ℚ) - 1)

end AgenticDS
