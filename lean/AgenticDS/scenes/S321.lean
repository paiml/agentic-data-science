/-
Copyright (c) 2026 Pragmatic AI Labs. All rights reserved.
Released under MIT license as described in the file LICENSE.
Authors: Pragmatic AI Labs
-/
import AgenticDS.Examples.M3V05

/-! # Scene 3.2.1: decide is checked by the kernel

Run from `lean/AgenticDS`: `lake env lean scenes/S321.lean`.
Provable contract: the kernel's record of `m3v05_ne` lists only
the standard axioms (`propext`, `Classical.choice`, `Quot.sound`).
A `native_decide` proof adds a compiler axiom and a `sorry` adds
`sorryAx`, so either one fails this check. Writes nothing. -/

#print axioms m3v05_ne

open Lean Elab Command in
/-- The decide proof rests on no axiom outside the standard three. -/
def kernelChecked (n : Name) : CommandElabM Unit := do
  let ok := [``propext, ``Classical.choice, ``Quot.sound]
  let ax ← collectAxioms n
  unless (← getEnv).contains n && ax.all ok.contains do
    throwError "contract ads-lean-s321-decide-v1 violated: {ax.toList}"
  IO.println "contract: ads-lean-s321-decide-v1 OK"

#eval kernelChecked ``m3v05_ne
