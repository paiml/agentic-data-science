/-
Copyright (c) 2026 Pragmatic AI Labs. All rights reserved.
Released under MIT license as described in the file LICENSE.
Authors: Pragmatic AI Labs
-/
import AgenticDS.Examples.M2
import AgenticDS.Examples.Run

/-! Entry point of `lake exe example-m2 <id>`. -/

def main (args : List String) : IO UInt32 :=
  runExample examplesM2 args
