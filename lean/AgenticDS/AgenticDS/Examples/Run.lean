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

/-- The contract line of a demo: refuse (exit 1 through
`runExample`) unless `ok`, else print `contract: NAME OK`. -/
def contract (name : String) (ok : Bool) : IO Unit := do
  unless ok do throw (IO.userError s!"contract {name} violated")
  IO.println s!"contract: {name} OK"

/-- `p.isInfixOf s`: the text `p` occurs inside `s`. -/
def String.isInfixOf (p s : String) : Bool :=
  (s.splitOn p).length > 1

/-- True when the SVG at `path` is a plot: at least two points
(circles or bars) and at least eight text labels. -/
def plotOk (path : String) : IO Bool := do
  let s ← IO.FS.readFile path
  let n := fun (p : String) => (s.splitOn p).length - 1
  pure (n "<circle" + n "<rect x=" ≥ 2 && n "<text" ≥ 8)
