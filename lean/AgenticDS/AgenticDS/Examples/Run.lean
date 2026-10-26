/-
Copyright (c) 2026 Pragmatic AI Labs. All rights reserved.
Released under MIT license as described in the file LICENSE.
Authors: Pragmatic AI Labs
-/
import Mathlib

/-! # Example runner

`lake exe example-mN <id>` runs one example of module N. -/

/-- Run the example named by the single argument. -/
def runExample (examples : List (String × IO Unit))
    (args : List String) : IO UInt32 := do
  match args with
  | [id] =>
    match examples.lookup id with
    | some act =>
      try act; pure 0 catch e =>
        IO.eprintln s!"FAIL {id}: {e}"; pure 1
    | none => IO.eprintln s!"unknown example {id}"; pure 1
  | _ =>
    IO.eprintln s!"usage: example <id>; ids: {examples.map (·.1)}"
    pure 1
