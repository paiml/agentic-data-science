/-
Copyright (c) 2026 Pragmatic AI Labs. All rights reserved.
Released under MIT license as described in the file LICENSE.
Authors: Pragmatic AI Labs
-/
import AgenticDS.Examples.M1

/-! Module 1 example checks: registry, values, every example
runs. -/

open AgenticDS

-- Lines each example must print.
def m1Want : List (String × List String) := [
  ("v01", ["mean     = 5", "variance = 4"]),
  ("v03", ["leanprover/lean4:v4.35.0"])]

def main (_ : List String) : IO UInt32 := do
  let mut ok := true
  let dir : System.FilePath := "AgenticDS/Examples"
  let files := ((← dir.readDir).filter
    fun e => e.fileName.startsWith "M1V").size
  if files != examplesM1.length then
    IO.eprintln s!"FAIL {files} files, {examplesM1.length} examples"
    ok := false
  if mean m1v01_xs != 5 || variance m1v01_xs != 4 then
    IO.eprintln "FAIL mean/variance of the example data"
    ok := false
  if m1v02_third != 1 || m1v02_float != false then
    IO.eprintln "FAIL exact rationals against Float"
    ok := false
  if (← m1v03_pin) != "leanprover/lean4:v4.35.0\n" then
    IO.eprintln "FAIL toolchain pin"
    ok := false
  let ax ← m1v07_axioms `AgenticDS.variance_shift
  if ax.contains `sorryAx || ax.length == 0 then
    IO.eprintln s!"FAIL axioms {ax}"
    ok := false
  for (id, act) in examplesM1 do
    try
      let (out, _) ← IO.FS.withIsolatedStreams act
      for w in (m1Want.lookup id).getD [] do
        unless (out.splitOn w).length > 1 do
          IO.eprintln s!"FAIL {id} lacks {w}"; ok := false
    catch e => IO.eprintln s!"FAIL {id}: {e}"; ok := false
  if ok then IO.println "contract: ads-lean-examples-m1-v1 OK"
  pure (if ok then 0 else 1)
