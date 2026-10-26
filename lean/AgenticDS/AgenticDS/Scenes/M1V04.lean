import Mathlib
/-! Why the gate counts the unfinished-proof word. -/

-- The compiler only warns about an unfinished proof,
-- so the gate also scans every source for the word,
-- for native-code proofs and for unfinished-work markers.
-- The terminal runs that scan: make lean-scan.
def m1v04 : IO Unit := pure ()
