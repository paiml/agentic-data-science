import Mathlib

namespace AgenticDS

/-! M3: nearest-centroid assignment for any cost, and its optimality. -/

section Assign
variable {α β : Type*}

/-- Smallest cost from `x` to any centroid in `c0 :: cs`. -/
def minCost (cost : α → β → ℚ) (x : α) (c0 : β) (cs : List β) : ℚ :=
  cs.foldl (fun m c => min m (cost x c)) (cost x c0)

/-- Sum over points of the cost to the nearest centroid. -/
def objective (cost : α → β → ℚ) (c0 : β) (cs : List β) (pts : List α) : ℚ :=
  (pts.map fun x => minCost cost x c0 cs).sum

theorem foldl_min_le (cost : α → β → ℚ) (x : α) (cs : List β) :
    ∀ init : ℚ, cs.foldl (fun m c => min m (cost x c)) init ≤ init ∧
      ∀ c ∈ cs, cs.foldl (fun m c => min m (cost x c)) init ≤ cost x c := by
  induction cs with
  | nil => intro init; simp
  | cons h t ih =>
    intro init
    obtain ⟨h1, h2⟩ := ih (min init (cost x h))
    refine ⟨?_, ?_⟩
    · simp only [List.foldl_cons]; exact h1.trans (min_le_left _ _)
    · intro c hc
      simp only [List.foldl_cons]
      rcases List.mem_cons.mp hc with rfl | hc
      · exact h1.trans (min_le_right _ _)
      · exact h2 c hc

theorem minCost_le (cost : α → β → ℚ) (x : α) (c0 : β) (cs : List β) (c : β)
    (hc : c ∈ c0 :: cs) : minCost cost x c0 cs ≤ cost x c := by
  unfold minCost
  obtain ⟨h1, h2⟩ := foldl_min_le cost x cs (cost x c0)
  rcases List.mem_cons.mp hc with rfl | hc
  · exact h1
  · exact h2 c hc

/-- T6: assigning every point to its nearest centroid never does worse than any other
assignment `f` to the same centroids (the assignment step does not increase the objective). -/
theorem assign_step_optimal (cost : α → β → ℚ) (c0 : β) (cs : List β) (pts : List α) (f : α → β)
    (hf : ∀ x ∈ pts, f x ∈ c0 :: cs) :
    objective cost c0 cs pts ≤ (pts.map fun x => cost x (f x)).sum := by
  unfold objective
  exact List.sum_le_sum (fun x hx => minCost_le cost x c0 cs (f x) (hf x hx))

end Assign

/-- Index of the nearest centroid; ties go to the lowest index (R's `max.col(ties = "first")`). -/
def nearestIdx (cost : List ℚ → List ℚ → ℚ) (x : List ℚ) (cs : List (List ℚ)) : ℕ :=
  (cs.zipIdx.foldl (fun (b : ℕ × ℚ) (p : List ℚ × ℕ) =>
    if cost x p.1 < b.2 then (p.2, cost x p.1) else b) (0, 1000000000000000000000000)).1

/-- Weighted squared distance; with weights `1 / variance` it equals the z-scored distance. -/
def wdist (w x c : List ℚ) : ℚ := (List.zipWith (fun wj p => wj * (p.1 - p.2) ^ 2) w (x.zip c)).sum

/-- Mean of a non-empty list of equal-length vectors, column by column. -/
def meanVec (d : ℕ) (vs : List (List ℚ)) : List ℚ :=
  (List.range d).map fun j => (vs.map (·.getD j 0)).sum / (vs.length : ℚ)

/-- One Lloyd step: assign, then move each centroid to the mean of its members (empty keeps). -/
def lloydStep (w : List ℚ) (pts cs : List (List ℚ)) : List ℕ × List (List ℚ) :=
  let cl := pts.map (nearestIdx (wdist w) · cs)
  let cs' := cs.zipIdx.map fun (c, k) =>
    let mem := (pts.zip cl).filter (·.2 = k) |>.map Prod.fst
    if mem = [] then c else meanVec w.length mem
  (cl, cs')

/-- Lloyd iterations until the assignment repeats (fuel-bounded). -/
def lloyd (w : List ℚ) (pts : List (List ℚ)) : ℕ → List ℕ → List (List ℚ) → List ℕ × List (List ℚ)
  | 0, cl, cs => (cl, cs)
  | n + 1, cl, cs =>
    let (cl', cs') := lloydStep w pts cs
    if cl' = cl then (cl, cs) else lloyd w pts n cl' cs'

end AgenticDS
