/-
Copyright (c) 2026 Pragmatic AI Labs. All rights reserved.
Released under MIT license as described in the file LICENSE.
Authors: Pragmatic AI Labs
-/
import AgenticDS.Pipeline

/-! # Scene 4.1.0: the surface of Pipeline.lean

Run from `lean/AgenticDS`: `lake env lean scenes/S410.lean`.
Provable contract: the module defines the row structures, the
validate, clean, split and fit functions, and theorems about
clean and the split, read from the environment. Writes nothing. -/

open Lean Elab Command in
/-- Each named declaration exists and comes from the Pipeline
module; theorems are theorems. -/
def surface : CommandElabM Unit := do
  let env ← getEnv
  let some m := env.getModuleIdx? `AgenticDS.Pipeline
    | throwError "no module AgenticDS.Pipeline"
  let defs := [``AgenticDS.ValidRow, ``AgenticDS.validate,
    ``AgenticDS.clean, ``AgenticDS.trainRows,
    ``AgenticDS.testRows, ``AgenticDS.fitCoefs]
  let thms := [``AgenticDS.clean_length_le,
    ``AgenticDS.clean_sub, ``AgenticDS.split_partition]
  let mut ok := true
  for n in defs ++ thms do
    let here := env.getModuleIdxFor? n == some m
    IO.println s!"{n.toString} {if here then "found" else "MISSING"}"
    ok := ok && here
  for n in thms do
    ok := ok && (env.find? n).any (·.isTheorem)
  unless ok do throwError "contract ads-lean-s410-surface-v1 violated"
  IO.println "contract: ads-lean-s410-surface-v1 OK"

#eval surface
