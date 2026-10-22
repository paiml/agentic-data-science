import AgenticDS.Confusion

namespace AgenticDS

/-- A labelled row: feature vector and species. -/
abbrev Row := List ℚ × Species

inductive Tree
  | leaf (cls : Species)
  | node (feat : ℕ) (thr : ℚ) (l r : Tree)
  deriving Repr

def Tree.predict : Tree → List ℚ → Species
  | .leaf c, _ => c
  | .node f t l r, x => if x.getD f 0 < t then l.predict x else r.predict x

def countCls (rows : List Row) (s : Species) : ℕ := rows.countP (fun r => decide (r.2 = s))

/-- n * gini impurity: n - (sum of squared class counts) / n. -/
def dev (rows : List Row) : ℚ :=
  if rows.isEmpty then 0
  else (rows.length : ℚ) - (Species.all.map fun s => ((countCls rows s : ℕ) : ℚ) ^ 2).sum / rows.length

/-- Majority class; ties go to the first class in `Species.all` (rpart's level order). -/
def majority (rows : List Row) : Species :=
  (Species.all.foldl (fun (b : Species × ℕ) s =>
    if countCls rows s > b.2 then (s, countCls rows s) else b) (.adelie, 0)).1

def sortedVals (rows : List Row) (f : ℕ) : List ℚ :=
  ((rows.map (·.1.getD f 0)).toArray.qsort (· < ·)).toList.eraseDups

def thresholds (rows : List Row) (f : ℕ) : List ℚ :=
  let v := sortedVals rows f
  (v.zip v.tail).map fun (a, b) => (a + b) / 2

/-- Best split by gini improvement; first feature then lowest threshold wins ties. -/
def bestSplit (rows : List Row) (nfeat minBucket : ℕ) : Option (ℕ × ℚ × ℚ) :=
  (List.range nfeat).foldl (fun best f =>
    (thresholds rows f).foldl (fun best t =>
      let l := rows.filter fun r => r.1.getD f 0 < t
      let r := rows.filter fun r => ¬ (r.1.getD f 0 < t)
      if l.length < minBucket ∨ r.length < minBucket then best
      else
        let imp := dev rows - dev l - dev r
        match best with
        | none => some (f, t, imp)
        | some (_, _, bi) => if imp > bi then some (f, t, imp) else best) best) none

/-- Greedy CART with rpart's defaults: minsplit 20, minbucket 7, cp 0.01 of the root deviance. -/
def grow (nfeat : ℕ) (rootDev : ℚ) : ℕ → List Row → Tree
  | 0, rows => .leaf (majority rows)
  | fuel + 1, rows =>
    if rows.length < 20 ∨ dev rows = 0 then .leaf (majority rows)
    else match bestSplit rows nfeat 7 with
      | some (f, t, imp) =>
        if imp / rootDev ≥ 1 / 100 then
          .node f t (grow nfeat rootDev fuel (rows.filter fun r => r.1.getD f 0 < t))
                    (grow nfeat rootDev fuel (rows.filter fun r => ¬ (r.1.getD f 0 < t)))
        else .leaf (majority rows)
      | none => .leaf (majority rows)

/-- rpart scales `cp` by the root node's misclassification risk, not its gini deviance. -/
def rootRisk (rows : List Row) : ℚ := (rows.length : ℚ) - (countCls rows (majority rows) : ℚ)


def Tree.leaves : Tree → ℕ
  | .leaf _ => 1
  | .node _ _ l r => l.leaves + r.leaves

/-- Rows the tree misclassifies. -/
def errs (t : Tree) (rows : List Row) : ℕ := rows.countP fun r => decide (t.predict r.1 ≠ r.2)

/-- rpart's cost-complexity cut at `cp`: collapse a subtree whose misclassification saving per
extra leaf is below `cp` times the root risk (bottom-up). -/
def prune (cutoff : ℚ) : Tree → List Row → Tree
  | .leaf c, _ => .leaf c
  | .node f t l r, rows =>
    let sub := Tree.node f t (prune cutoff l (rows.filter fun x => x.1.getD f 0 < t))
                             (prune cutoff r (rows.filter fun x => ¬ (x.1.getD f 0 < t)))
    let saving : ℚ := (rows.length : ℚ) - (countCls rows (majority rows) : ℚ) - (errs sub rows : ℕ)
    if saving < cutoff * ((sub.leaves : ℚ) - 1) then .leaf (majority rows) else sub

def fitTree (rows : List Row) : Tree :=
  prune (rootRisk rows / 100) (grow 4 (rootRisk rows) 10 rows) rows

end AgenticDS
