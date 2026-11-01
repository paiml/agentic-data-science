/-
Copyright (c) 2026 Pragmatic AI Labs. All rights reserved.
Released under MIT license as described in the file LICENSE.
Authors: Pragmatic AI Labs
-/
import Mathlib

/-! # Text plots: block-character bars

A bar is `n` copies of `█`, so its length is its value. `width`
scales a count into a bar of at most `w` blocks, never zero for a
nonzero count. `plot` prints the rows and checks the contract
`plot_bars_bounded` before it says so. -/

namespace AgenticDS

/-- A bar of `n` full blocks. -/
def bar (n : Nat) : String := String.ofList (List.replicate n '█')

/-- The bar holds exactly as many blocks as its value. -/
theorem bar_length (n : Nat) : (bar n).length = n := by
  simp [bar]

/-- Blocks for count `n` when the largest count `m` gets `w`
blocks; a nonzero count always shows at least one block. -/
def width (w m n : Nat) : Nat :=
  if n = 0 then 0 else max 1 (n * w / max m 1)

/-- Print a bar and its count for each row, then check the
contract: no bar is longer than `w`, zero shows nothing, nonzero
shows something, and the longest count fills the width. -/
def plot (w : Nat) (rows : List (String × Nat)) : IO Unit := do
  let m := (rows.map (·.2)).foldl max 0
  for (l, n) in rows do
    IO.println s!"{l} {bar (width w m n)} {n}"
  let ok := rows.all fun (_, n) =>
    let k := width w m n
    k ≤ w && (n = 0) == (k = 0) && (n ≠ m || k = w)
  assert! ok
  IO.println "contract: plot_bars_bounded OK"

end AgenticDS
