import AgenticDS.Pipeline
import AgenticDS.Examples.Scat
/-! Pipeline.lean: every declaration, in file order. -/

-- You list every structure, def and theorem of
-- AgenticDS/Pipeline.lean with grep, in file order.
def m4v01 : IO Unit :=
  wineDemo "plot-m4v01.svg" "Red wine: volatile acidity and quality"
    "volatile_acidity" 1 8
