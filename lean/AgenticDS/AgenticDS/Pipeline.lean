/-
Copyright (c) 2026 Pragmatic AI Labs. All rights reserved.
Released under MIT license as described in the file LICENSE.
Authors: Pragmatic AI Labs
-/
import AgenticDS.Csv

/-! # The wine pipeline: validate, clean, split, fit, score

Every step sits next to a statement about it. All arithmetic is
exact over ℚ. -/

namespace AgenticDS

/-- An untrusted row: a missing value is `none`. -/
structure WineRaw where
  features : List (Option ℚ)
  quality : Option ℚ
  color : String

/-- A trusted row: the invariants are proof fields. -/
structure ValidRow where
  features : List ℚ
  quality : ℚ
  white : Bool
  h_len : features.length = 11
  h_q : 0 ≤ quality ∧ quality ≤ 10

/-- Refuse (never repair) a row that breaks an invariant. -/
def validate : WineRaw → Option ValidRow
  | ⟨fs?, q?, c⟩ =>
    match fs?.mapM id, q?, c with
    | some fs, some q, c =>
      if hl : fs.length = 11 then
        if hq : 0 ≤ q ∧ q ≤ 10 then
          if c = "red" then some ⟨fs, q, false, hl, hq⟩
          else if c = "white" then some ⟨fs, q, true, hl, hq⟩
          else none
        else none
      else none
    | _, _, _ => none

def clean (rs : List WineRaw) : List ValidRow :=
  rs.filterMap validate

theorem clean_length_le (rs : List WineRaw) :
    (clean rs).length ≤ rs.length :=
  List.length_filterMap_le _ _

/-- Nothing is invented: every output row comes from an input. -/
theorem clean_sub (rs : List WineRaw) (v : ValidRow)
    (h : v ∈ clean rs) : ∃ r ∈ rs, validate r = some v :=
  List.mem_filterMap.mp h

/-- Nothing valid is lost. -/
theorem clean_complete (rs : List WineRaw) (r : WineRaw)
    (v : ValidRow) (hr : r ∈ rs) (hv : validate r = some v) :
    v ∈ clean rs :=
  List.mem_filterMap.mpr ⟨r, hr, hv⟩

theorem clean_in_range (rs : List WineRaw) (v : ValidRow)
    (_ : v ∈ clean rs) : 0 ≤ v.quality ∧ v.quality ≤ 10 :=
  v.h_q

/-- Every fifth row (the 5th, 10th, ...) is a test row. -/
def isTest (i : ℕ) : Bool := (i + 1) % 5 == 0

def trainRows {α : Type*} (l : List α) : List α :=
  (l.zipIdx.filter fun p => !isTest p.2).map (·.1)

def testRows {α : Type*} (l : List α) : List α :=
  (l.zipIdx.filter fun p => isTest p.2).map (·.1)

theorem length_filter_split {β : Type*} (p : β → Bool)
    (l : List β) :
    (l.filter fun x => !p x).length + (l.filter p).length
      = l.length := by
  induction l with
  | nil => simp
  | cons x t ih => cases h : p x <;> simp [h] <;> omega

/-- Train and test together are exactly the whole list. -/
theorem split_partition {α : Type*} (l : List α) :
    (trainRows l).length + (testRows l).length = l.length := by
  have := length_filter_split (fun p : α × ℕ => isTest p.2) l.zipIdx
  simpa [trainRows, testRows] using this

/-- Intercept, the 11 features, then the colour indicator. -/
def design (r : ValidRow) : List ℚ :=
  1 :: r.features ++ [if r.white then 1 else 0]

/-- Gauss-Jordan elimination over ℚ: no rounding anywhere. -/
def gaussSolve (a : List (List ℚ)) (b : List ℚ) :
    Option (List ℚ) := Id.run do
  let n := a.length
  let mut m : Array (Array ℚ) :=
    ((a.zip b).map fun p => (p.1 ++ [p.2]).toArray).toArray
  for c in [0:n] do
    let ok := fun r => (m[r]!)[c]! != 0
    match (List.range' c (n - c)).find? ok with
    | none => return none
    | some p =>
      m := m.swapIfInBounds c p
      let pv := (m[c]!)[c]!
      m := m.set! c (m[c]!.map (· / pv))
      for r in [0:n] do
        if r ≠ c then
          let f := (m[r]!)[c]!
          let g := fun x y => x - f * y
          m := m.set! r (Array.zipWith g m[r]! m[c]!)
  return some (m.toList.map fun r => r[n]!)

/-- Normal equations XᵀX β = Xᵀy, solved exactly. -/
def fitCoefs (rows : List ValidRow) : Option (List ℚ) :=
  let ds := rows.map design
  let k := 12 + 1
  let xtx := (List.range k).map fun i => (List.range k).map fun j =>
    (ds.map fun d => d[i]! * d[j]!).sum
  let xty := (List.range k).map fun i =>
    ((ds.zip rows).map fun p => p.1[i]! * p.2.quality).sum
  gaussSolve xtx xty

def predictRow (β : List ℚ) (r : ValidRow) : ℚ :=
  ((β.zip (design r)).map fun p => p.1 * p.2).sum

/-- Sum of squared errors of the model on the rows. -/
def sseRows (β : List ℚ) (rows : List ValidRow) : ℚ :=
  (rows.map fun r => (r.quality - predictRow β r) ^ 2).sum

/-- Total sum of squares about the mean quality of the rows. -/
def sstRows (rows : List ValidRow) : ℚ :=
  let m := (rows.map (·.quality)).sum / rows.length
  (rows.map fun r => (r.quality - m) ^ 2).sum

/-- Read one wine file (11 features, quality, colour). -/
def readWine (path : String) : IO (List WineRaw) := do
  let txt ← IO.FS.readFile path
  pure <| ((parseCsv txt).drop 1).map fun f =>
    ⟨(f.take 11).map parseRat, parseRat (f.getD 11 ""),
      f.getD 12 ""⟩

end AgenticDS
