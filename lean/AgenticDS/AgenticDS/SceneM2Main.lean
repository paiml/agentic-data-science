/-
Copyright (c) 2026 Pragmatic AI Labs. All rights reserved.
Released under MIT license as described in the file LICENSE.
Authors: Pragmatic AI Labs
-/
import AgenticDS.Scenes.M2
import AgenticDS.Scenes.Run

/-! Entry point of `lake exe scene-m2 <id>`. -/

def main (args : List String) : IO UInt32 :=
  runScene scenesM2 args
