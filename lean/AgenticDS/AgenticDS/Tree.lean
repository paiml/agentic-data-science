/-
Copyright (c) 2026 Pragmatic AI Labs. All rights reserved.
Released under MIT license as described in the file LICENSE.
Authors: Pragmatic AI Labs
-/
import AgenticDS.Confusion

/-! # CART classification tree

M3: the impurity `dev`, the split search with a minimum bucket
and a strict gain, cost-complexity pruning and `fitTree`. -/

namespace AgenticDS

/-- A training row: feature values and the species. -/
structure Row where
  x : List ℚ
  y : Species

/-- A tree: leaves predict a species, nodes split `x[j] ≤ t`. -/
inductive Tree where
  | leaf (c : Species)
  | node (j : ℕ) (t : ℚ) (l r : Tree)

/-- Rows of class `c`. -/
def countCls (rows : List Row) (c : Species) : ℕ :=
  rows.countP fun r => decide (r.y = c)

/-- `n` times the gini impurity: `n - (sum of counts²) / n`. -/
def dev (rows : List Row) : ℚ :=
  let sq := (Species.all.map fun c => (countCls rows c : ℚ) ^ 2).sum
  rows.length - sq / rows.length

/-- An empty node has no deviance. -/
theorem dev_nil : dev [] = 0 := by simp [dev]

theorem countCls_pure (rows : List Row) (c c' : Species)
    (h : ∀ r ∈ rows, r.y = c) :
    countCls rows c' = if c' = c then rows.length else 0 := by
  unfold countCls
  split_ifs with hc
  · subst hc
    rw [List.countP_eq_length.mpr]
    simpa using h
  · rw [List.countP_eq_zero]
    intro r hr
    simp [h r hr, Ne.symm hc]

/-- A node whose rows are one class has deviance `n - n = 0`. -/
theorem dev_pure (rows : List Row) (c : Species)
    (h : ∀ r ∈ rows, r.y = c) : dev rows = 0 := by
  by_cases hn : rows.length = 0
  · simp [dev, hn]
  · have hq : (rows.length : ℚ) ≠ 0 := by exact_mod_cast hn
    cases c <;>
      simp [dev, Species.all, countCls_pure rows _ _ h] <;>
      field_simp <;> ring

/-- The class with most rows; ties go to the earlier species. -/
def majority (rows : List Row) : Species :=
  Species.all.foldl
    (fun b c => if countCls rows b < countCls rows c then c else b)
    .adelie

/-- The species a tree predicts for features `x`. -/
def predict : Tree → List ℚ → Species
  | .leaf c, _ => c
  | .node j t l r, x => if x.getD j 0 ≤ t then predict l x
      else predict r x

/-- Rows the tree misclassifies. -/
def errs (t : Tree) (rows : List Row) : ℕ :=
  rows.countP fun r => decide (predict t r.x ≠ r.y)

/-- Number of leaves. -/
def Tree.leaves : Tree → ℕ
  | .leaf _ => 1
  | .node _ _ l r => l.leaves + r.leaves

/-- Rows going left and right of `x[j] ≤ t`. -/
def Row.goLeft (j : ℕ) (t : ℚ) (r : Row) : Bool :=
  decide (r.x.getD j 0 ≤ t)

/-- Best split `(feature, threshold)` leaving at least `mb` rows
on each side. A split is kept only when its gain is strictly
bigger, so ties go to the earlier feature and lower threshold. -/
def bestSplit (mb : ℕ) (rows : List Row) : Option (ℕ × ℚ) :=
  let nf := (rows.headD ⟨[], .adelie⟩).x.length
  let cands := (List.range nf).flatMap
    fun j => ((rows.map fun r => r.x.getD j 0).dedup.mergeSort
      (fun a b => decide (a ≤ b))).map fun t => (j, t)
  (cands.foldl (fun (b : Option (ℕ × ℚ) × ℚ) (j, t) =>
    let l := rows.filter (Row.goLeft j t)
    let r := rows.filter (fun s => !Row.goLeft j t s)
    let g := dev rows - dev l - dev r
    if mb ≤ l.length ∧ mb ≤ r.length ∧ b.2 < g then (some (j, t), g)
    else b) (none, 0)).1

/-- Grow a tree to depth at most `fuel`. -/
def grow (mb : ℕ) : ℕ → List Row → Tree
  | 0, rows => .leaf (majority rows)
  | fuel + 1, rows =>
    if dev rows = 0 then .leaf (majority rows) else
    match bestSplit mb rows with
    | none => .leaf (majority rows)
    | some (j, t) => .node j t
        (grow mb fuel (rows.filter (Row.goLeft j t)))
        (grow mb fuel (rows.filter fun s => !Row.goLeft j t s))

/-- Cost-complexity pruning: collapse a subtree whose saving is
below `cp` times its extra leaves. -/
def prune (cp : ℚ) : List Row → Tree → Tree
  | _, .leaf c => .leaf c
  | rows, .node j t l r =>
    let l' := prune cp (rows.filter (Row.goLeft j t)) l
    let r' := prune cp (rows.filter fun s => !Row.goLeft j t s) r
    let s := Tree.node j t l' r'
    let saving : ℚ := rows.length - countCls rows (majority rows)
      - errs s rows
    if saving < cp * ((s.leaves : ℚ) - 1) then .leaf (majority rows)
    else s

/-- Fit: grow, then prune at the root risk divided by 100. -/
def fitTree (mb fuel : ℕ) (rows : List Row) : Tree :=
  let risk : ℚ := rows.length - countCls rows (majority rows)
  prune (risk / 100) rows (grow mb fuel rows)

end AgenticDS
