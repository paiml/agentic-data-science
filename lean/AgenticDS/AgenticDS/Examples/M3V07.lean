import AgenticDS.Tree
/-! Pruning at cp, and fitTree. -/
open AgenticDS
-- Nine rows, one feature; the 48.5 adelie is an outlier.
def m3v07_rows : List Row :=
  let r (x : ℚ) (s : Species) : Row := ⟨[x], s⟩
  [r 38 .adelie, r 39 .adelie, r 40 .adelie, r 41 .adelie,
   r 48.5 .adelie, r 47 .gentoo, r 48 .gentoo,
   r 49 .gentoo, r 50 .gentoo]

-- Collapse a subtree when saving < cp * (leaves - 1).
-- fitTree prunes at the root risk divided by 100.
def m3v07 : IO Unit := do
  let rows := m3v07_rows
  let sh (t : Tree) :=
    s!"{t.leaves} leaves, {errs t rows} errors"
  IO.println s!"grown:   {sh (grow 1 5 rows)}"
  let t := prune 2 rows (grow 1 5 rows)
  IO.println s!"cp 2:    {sh t}"
  IO.println s!"fitTree: {sh (fitTree 1 5 rows)}"
