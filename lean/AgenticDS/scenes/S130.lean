/-
Copyright (c) 2026 Pragmatic AI Labs. All rights reserved.
Released under MIT license as described in the file LICENSE.
Authors: Pragmatic AI Labs
-/
import AgenticDS.Ols
import AgenticDS.OlsExample
import AgenticDS.Stats

/-! # Scene 1.3.0: what the proofs rest on

Run from `lean/AgenticDS`: `lake env lean scenes/S130.lean`.
Provable contract: each of the six theorems depends only on the
standard axioms `propext`, `Classical.choice` and `Quot.sound`,
read from the kernel's own record. Writes nothing. -/

open AgenticDS

#print axioms mean_const
#print axioms variance_nonneg
#print axioms variance_shift
#print axioms sum_residuals
#print axioms residuals_sum
#print axioms sum_map_add_const

open Lean Elab Command in
/-- Every named theorem's axioms lie in the standard three. -/
def axiomsCheck (ns : List Name) : CommandElabM Unit := do
  let ok := [``propext, ``Classical.choice, ``Quot.sound]
  let mut good := 0
  for n in ns do
    let ax ← collectAxioms n
    if ax.all ok.contains then good := good + 1
  unless good == ns.length && ns.length == 6 do
    throwError "contract ads-lean-s130-axioms-v1 violated"
  IO.println "contract: ads-lean-s130-axioms-v1 OK"

#eval axiomsCheck [``mean_const, ``variance_nonneg,
  ``variance_shift, ``sum_residuals, ``residuals_sum,
  ``sum_map_add_const]
