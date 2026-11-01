import Mathlib
import AgenticDS.Examples.Run
/-! The recap: the build, then the commit. -/

-- You run `lake build AgenticDS example-m2`,
-- then read
-- the last three commits with git.
def m2v10 : IO Unit := do
  let l ← IO.FS.readFile "lakefile.toml"
  contract "ads-lean-m2v10-v1" ("example-m2".isInfixOf l)
