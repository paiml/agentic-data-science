import AgenticDS.Tree
/-! Decide in the kernel; no native code. -/
open AgenticDS
-- decide is plain computation; as a proof, the kernel
-- re-checks it. Native code would never be re-checked.
theorem s3v05_ne : Species.adelie ≠ .gentoo := by decide

-- The terminal runs the gate's own marker scan: it fails
-- on any banned word in the sources.
def s3v05 : IO Unit := pure ()
