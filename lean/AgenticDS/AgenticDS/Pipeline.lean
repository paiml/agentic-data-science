import AgenticDS.Csv

namespace AgenticDS

/-! M4: data validity as types. A `ValidRow` cannot hold a missing value, a wrong feature count
or a quality outside 0..10, so everything downstream of `clean` never re-checks. -/

/-- A wine row as read: any field may be missing. -/
structure WineRaw where
  features : List (Option ℚ)
  quality : Option ℚ
  color : String

/-- A row that passed validation; the invariants are part of the type. -/
structure ValidRow where
  features : List ℚ
  quality : ℚ
  white : Bool
  h_len : features.length = 11
  h_q : 0 ≤ quality ∧ quality ≤ 10

/-- Validation: all eleven features present, quality in 0..10, colour red or white. -/
def validate (r : WineRaw) : Option ValidRow :=
  match r.features.mapM id, r.quality, r.color with
  | some fs, some q, c =>
    if hl : fs.length = 11 then
      if hq : 0 ≤ q ∧ q ≤ 10 then
        if c = "red" then some ⟨fs, q, false, hl, hq⟩
        else if c = "white" then some ⟨fs, q, true, hl, hq⟩
        else none
      else none
    else none
  | _, _, _ => none

def clean (rs : List WineRaw) : List ValidRow := rs.filterMap validate

/-- T8a: cleaning never grows the list. -/
theorem clean_length_le (rs : List WineRaw) : (clean rs).length ≤ rs.length :=
  List.length_filterMap_le _ _

/-- T8b: every cleaned row comes from an input row that validates to it. -/
theorem clean_sub (rs : List WineRaw) (v : ValidRow) (h : v ∈ clean rs) :
    ∃ r ∈ rs, validate r = some v := by
  obtain ⟨r, hr, hv⟩ := List.mem_filterMap.mp h
  exact ⟨r, hr, hv⟩

/-- T8c: nothing valid is dropped. -/
theorem clean_complete (rs : List WineRaw) (r : WineRaw) (v : ValidRow) (hr : r ∈ rs)
    (hv : validate r = some v) : v ∈ clean rs :=
  List.mem_filterMap.mpr ⟨r, hr, hv⟩

/-- T8d: the type carries the invariants, so any cleaned row is in range. -/
theorem clean_in_range (rs : List WineRaw) (v : ValidRow) (_ : v ∈ clean rs) :
    v.features.length = 11 ∧ 0 ≤ v.quality ∧ v.quality ≤ 10 :=
  ⟨v.h_len, v.h_q.1, v.h_q.2⟩

/-- Every fifth row (1-based) is a test row. -/
def isTest (i : ℕ) : Bool := (i + 1) % 5 == 0

def trainRows {α : Type*} (l : List α) : List α := (l.zipIdx.filter fun p => !isTest p.2).map Prod.fst
def testRows {α : Type*} (l : List α) : List α := (l.zipIdx.filter fun p => isTest p.2).map Prod.fst

theorem length_filter_split {α : Type*} (l : List α) (p : α → Bool) :
    (l.filter p).length + (l.filter fun x => !p x).length = l.length := by
  induction l with
  | nil => simp
  | cons h t ih =>
    by_cases hp : p h = true
    · simp [hp]; omega
    · have : p h = false := by simpa using hp
      simp [this]; omega

/-- T9: the split is a partition, so no row is both train and test and none is lost. -/
theorem split_partition {α : Type*} (l : List α) :
    (trainRows l).length + (testRows l).length = l.length := by
  unfold trainRows testRows
  simp only [List.length_map]
  rw [add_comm, length_filter_split l.zipIdx (fun p => isTest p.2)]
  simp

/-- Design row: intercept, the eleven features, colour dummy (red is the baseline). -/
def design (v : ValidRow) : List ℚ := 1 :: v.features ++ [if v.white then 1 else 0]

/-- Gauss-Jordan solve of `A x = b` in exact ℚ (first non-zero pivot). -/
def gaussSolve (A : List (List ℚ)) (b : List ℚ) : List ℚ := Id.run do
  let n := A.length
  let mut M : Array (Array ℚ) := (A.zip b).toArray.map fun (r, y) => (r ++ [y]).toArray
  for c in [0:n] do
    let mut p := c
    for r in [c:n] do
      if (M[p]!)[c]! = 0 && (M[r]!)[c]! ≠ 0 then p := r
    let tmp := M[c]!
    M := M.set! c M[p]!
    M := M.set! p tmp
    let pv := (M[c]!)[c]!
    M := M.set! c (M[c]!.map (· / pv))
    for r in [0:n] do
      if r ≠ c then
        let f := (M[r]!)[c]!
        if f ≠ 0 then
          M := M.set! r ((M[r]!.zip M[c]!).map fun (x, y) => x - f * y)
  return (M.toList.map fun r => r[n]!)

/-- Least-squares coefficients through the normal equations `XᵀX β = Xᵀy`. -/
def fitCoefs (rows : List ValidRow) : List ℚ :=
  let X := rows.map design
  let d := 13
  let A := (List.range d).map fun i => (List.range d).map fun j =>
    (X.map fun x => x.getD i 0 * x.getD j 0).sum
  let b := (List.range d).map fun i => ((X.zip rows).map fun (x, v) => x.getD i 0 * v.quality).sum
  gaussSolve A b

def predictRow (β : List ℚ) (v : ValidRow) : ℚ :=
  ((β.zip (design v)).map fun (a, x) => a * x).sum

def sseRows (β : List ℚ) (rows : List ValidRow) : ℚ :=
  (rows.map fun v => (v.quality - predictRow β v) ^ 2).sum

def sstRows (rows : List ValidRow) : ℚ :=
  let m := (rows.map (·.quality)).sum / (rows.length : ℚ)
  (rows.map fun v => (v.quality - m) ^ 2).sum

def readWine (txt : String) : List WineRaw :=
  (parseCsv txt).drop 1 |>.filterMap fun f =>
    if f.length = 13 then
      some ⟨(f.take 11).map fun s => if s = "NA" || s = "" then none else parseRat s,
        if f[11]! = "NA" || f[11]! = "" then none else parseRat f[11]!, f[12]!⟩
    else none

end AgenticDS
