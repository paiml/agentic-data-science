import AgenticDS.Tree
import AgenticDS.Examples.Scat
/-! Decide in the kernel; no native code. -/
open AgenticDS
-- decide is plain computation; as a proof, the kernel
-- re-checks it. Native code would never be re-checked.
theorem m3v05_ne : Species.adelie ≠ .gentoo := by decide

-- You run the gate's own marker scan: it fails
-- on any banned word in the sources.
def m3v05 : IO Unit :=
  penguinDemo "plot-m3v05.svg" "Penguins: bill length and depth"
    "bill_length_mm" "bill_depth_mm" 4
