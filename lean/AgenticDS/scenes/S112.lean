/-
Copyright (c) 2026 Pragmatic AI Labs. All rights reserved.
Released under MIT license as described in the file LICENSE.
Authors: Pragmatic AI Labs
-/
import Lean

/-! # Scene 1.1.2: the toolchain pin

Run from `lean/AgenticDS`: `lake env lean scenes/S112.lean`.
Provable contract: the release named in `lean-toolchain` is the
Lean that is elaborating this file. Writes nothing. -/

/-- The pin file's one line, and the running Lean's version. -/
def pinCheck : IO Unit := do
  let pin := (← IO.FS.readFile "lean-toolchain").trimAscii.toString
  let want := s!"leanprover/lean4:v{Lean.versionString}"
  IO.println s!"pinned  {pin}"
  IO.println s!"running {want}"
  unless pin == want do
    throw (IO.userError "contract ads-lean-s112-pin-v1 violated")
  IO.println "contract: ads-lean-s112-pin-v1 OK"

#eval pinCheck
