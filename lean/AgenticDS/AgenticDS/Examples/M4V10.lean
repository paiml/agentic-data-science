import AgenticDS.Pipeline
import AgenticDS.Examples.Scat
/-! The gate: the build, the axiom check, the tests. -/

-- You run the real gate, make gate-lean, and
-- shows its four stages and its exit status.
def m4v10 : IO Unit :=
  wineDemo "plot-m4v10.svg" "Red wine: pH and quality"
    "pH" 8 8
