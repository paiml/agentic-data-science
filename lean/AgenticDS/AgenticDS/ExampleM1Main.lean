/-
Copyright (c) 2026 Pragmatic AI Labs. All rights reserved.
Released under MIT license as described in the file LICENSE.
Authors: Pragmatic AI Labs
-/
import AgenticDS.Examples.M1

/-! Entry point of `lake exe example-m1 <id>`. -/

def main (args : List String) : IO UInt32 :=
  runExample examplesM1 args
