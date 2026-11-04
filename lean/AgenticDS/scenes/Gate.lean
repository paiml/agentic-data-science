/-
Copyright (c) 2026 Pragmatic AI Labs. All rights reserved.
Released under MIT license as described in the file LICENSE.
Authors: Pragmatic AI Labs
-/
import AgenticDS
import AgenticDS.OlsExample
import AgenticDS.Pipeline

/-! # Scenes 1.3.2, 3.3.3, 4.3.3: after the gate

Run from `lean/AgenticDS`, after `make gate-lean`:
`lake env lean scenes/Gate.lean`.
Provable contract: every theorem the gate's axiom scripts list
rests only on `propext`, `Classical.choice` and `Quot.sound`,
read from the kernel. Writes nothing. -/

open Lean Elab Command in
/-- Count every `AgenticDS` theorem in the loaded modules and
check its axioms. -/
def gateAxioms : CommandElabM Unit := do
  let env ← getEnv
  let ok := [``propext, ``Classical.choice, ``Quot.sound]
  let mut n := 0
  let mut bad : List Name := []
  for (c, i) in env.constants.map₁.toList do
    if i.isTheorem && (`AgenticDS).isPrefixOf c
        && !c.isInternalDetail then
      n := n + 1
      unless (← collectAxioms c).all ok.contains do
        bad := c :: bad
  IO.println s!"{n} theorems, {bad.length} outside the standard axioms"
  unless n > 0 && bad.isEmpty do
    throwError "contract ads-lean-gate-axioms-v1 violated: {bad}"
  IO.println "contract: ads-lean-gate-axioms-v1 OK"

#eval gateAxioms
