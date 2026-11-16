import AgenticDS.Examples.Run
import AgenticDS.Pipeline
import AgenticDS.Examples.Scat
/-! The gate: the build, the trust check, the tests. -/

-- You run the real gate, make gate-lean, and
-- shows its four stages and its exit status.
def m4v10 : IO Unit := do
  wineDemo "plot-m4v10.svg" "Red wine: pH and quality"
    "pH" 8 8
  contract "ads-lean-m4v10-v1"
    (← plotOk "plot-m4v10.svg")
