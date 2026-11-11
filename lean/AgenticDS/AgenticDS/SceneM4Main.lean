/-
Copyright (c) 2026 Pragmatic AI Labs. All rights reserved.
Released under MIT license as described in the file LICENSE.
Authors: Pragmatic AI Labs
-/
import AgenticDS.Scenes.M4

/-! Entry point of `lake exe scene-m4 <id>`. -/

def main (args : List String) : IO UInt32 :=
  runScene scenesM4 args
