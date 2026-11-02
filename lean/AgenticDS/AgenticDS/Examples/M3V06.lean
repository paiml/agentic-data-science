import AgenticDS.Examples.Run
import AgenticDS.Tree
import AgenticDS.Plot
/-! Gini deviance and the best split. -/
open AgenticDS
-- dev = n - (sum of squared class counts) / n.
-- A pure node gives n - n = 0: the signal to stop growing.
theorem m3v06_pure (rows : List Row) (c : Species)
    (h : ∀ r ∈ rows, r.y = c) : dev rows = 0 :=
  dev_pure rows c h

def m3v06_rows : List Row :=
  [⟨[38], .adelie⟩, ⟨[39], .adelie⟩, ⟨[40], .adelie⟩,
   ⟨[47], .gentoo⟩, ⟨[48], .gentoo⟩, ⟨[49], .gentoo⟩]

-- bestSplit: strict gain, at least mb rows a side.
def m3v06 : IO Unit := do
  let rows := m3v06_rows
  IO.println s!"dev empty: {dev []}"
  IO.println s!"dev left:  {dev (rows.take 3)}"
  IO.println s!"dev all:   {dev rows}"
  IO.println s!"split, minbucket 1: {bestSplit 1 rows}"
  IO.println s!"split, minbucket 4: {bestSplit 4 rows}"
  let gain := fun (t : Nat) =>
    let l := rows.filter fun r => r.x.headD 0 ≤ (t : ℚ)
    let r := rows.filter fun r => (t : ℚ) < r.x.headD 0
    (t.toFloat, qf (dev l + dev r))
  let cs := (List.range 12).map fun i => gain (37 + i)
  writeScatterDerived
    "plot-m3v06.svg" "Deviance after a split"
    "threshold (mm)" "left plus right deviance" cs cs []
    [s!"dev all = {dev rows}"]
  contract "ads-lean-m3v06-v1"
    (cs.all (fun p => p.2 ≤ qf (dev rows)) &&
      (← plotOk "plot-m3v06.svg"))
