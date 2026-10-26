import Mathlib
/-! The four gate checks. -/

-- The gate runs four checks; each one can fail:
--   1 build   warnings are errors
--   2 scan    no unfinished-proof or SATD markers
--   3 axioms  only propext, choice, Quot.sound
--   4 golden parity against the R numbers
-- The terminal runs the real gate: make gate-lean.
def m1v09 : IO Unit := pure ()
