import Mathlib
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
  if want != seen then
    throw (IO.userError "confusion differs")
  IO.println "ok confusion"
