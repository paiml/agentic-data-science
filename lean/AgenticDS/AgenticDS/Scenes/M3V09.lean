import AgenticDS.Examples.Run
import Mathlib
/-! A mutant: change one golden row in memory. -/
open Lean
-- sed: first row 37, 0, 0 becomes 36, 1, 0.
def s3v09_mutate (s : String) : String :=
  s.replace "[37, 0, 0]" "[36, 1, 0]"

def s3v09_matrix (s : String) :
    Except String (List (List Nat)) :=
  Json.parse s >>=
    (·.getObjValAs? (List (List Nat)) "confusion")

-- Observed is golden, expected is mutated: refused.
-- No file on disk changes.
def s3v09 : IO Unit := do
  let s ← IO.FS.readFile
    "../../datasets/golden/p3.json"
  let seen ← IO.ofExcept (s3v09_matrix s)
  let want ← IO.ofExcept (s3v09_matrix (s3v09_mutate s))
  IO.println s!"expected: {want}"
  IO.println s!"observed: {seen}"
  refuseUnless (want == seen) "confusion differs"
  IO.println "ok confusion"
