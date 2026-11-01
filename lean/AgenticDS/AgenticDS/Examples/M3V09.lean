import Mathlib
import AgenticDS.Examples.Scat
/-! A mutant: change one golden row in memory. -/
open Lean
-- sed: first row 37, 0, 0 becomes 36, 1, 0.
def m3v09_mutate (s : String) : String :=
  s.replace "[37, 0, 0]" "[36, 1, 0]"

def m3v09_matrix (s : String) :
    Except String (List (List Nat)) :=
  Json.parse s >>=
    (·.getObjValAs? (List (List Nat)) "confusion")

-- Observed is golden, expected is mutated: refused.
-- No file on disk changes.
def m3v09 : IO Unit := do
  let s ← IO.FS.readFile
    "../../datasets/golden/p3.json"
  let seen ← IO.ofExcept (m3v09_matrix s)
  let want ← IO.ofExcept (m3v09_matrix (m3v09_mutate s))
  IO.println s!"expected: {want}"
  IO.println s!"observed: {seen}"
  penguinDemo "plot-m3v09.svg" "Penguins: bill depth and flipper"
    "bill_depth_mm" "flipper_length_mm" 4
  -- The demo is the refusal: a mismatch is caught and
  -- reported, so the run is the same every time. A mutant
  -- that is NOT caught is the failure.
  if want != seen then
    IO.println "refused: confusion differs"
  else
    throw (IO.userError "mutant not caught")
