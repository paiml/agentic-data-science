/-
Copyright (c) 2026 Pragmatic AI Labs. All rights reserved.
Released under MIT license as described in the file LICENSE.
Authors: Pragmatic AI Labs
-/
import Mathlib

/-! # Scene runner

`lake exe scene-mN <id>` runs one on-camera scene of module N.
Each scene file stays within 25 lines of 59 columns so the
recording shows it whole. -/

/-- Run the scene named by the single argument. A recording
never starts inside the gate (`ADS_GATE_RUNNING`). -/
def runScene (scenes : List (String × IO Unit))
    (args : List String) : IO UInt32 := do
  if (← IO.getEnv "ADS_GATE_RUNNING").isSome then
    IO.eprintln "refused: ADS_GATE_RUNNING is set"
    return 1
  match args with
  | [id] =>
    match scenes.lookup id with
    | some act =>
      try act; pure 0 catch e =>
        IO.eprintln s!"FAIL {id}: {e}"; pure 1
    | none => IO.eprintln s!"unknown scene {id}"; pure 1
  | _ =>
    IO.eprintln s!"usage: scene <id>; ids: {scenes.map (·.1)}"
    pure 1

/-- Lines of a source file that break the 25 x 59 scene shape. -/
def shapeFaults (path : String) : IO (List String) := do
  let lines := (← IO.FS.readFile path).splitOn "\n"
  let lines := if lines.getLast? == some "" then lines.dropLast
    else lines
  let tall := if lines.length > 25 then [s!"{path}: lines"] else []
  let wide := lines.filter (·.length > 59)
  pure (tall ++ wide.map fun l => s!"{path}: wide: {l}")

/-- Every `Scenes/M<m>V*.lean` file keeps the shape. -/
def moduleShape (m : Nat) : IO (Nat × List String) := do
  let dir : System.FilePath := "AgenticDS/Scenes"
  let files := (← dir.readDir).filter fun e =>
    e.fileName.startsWith s!"M{m}V"
  let mut faults := []
  for e in files do
    faults := faults ++ (← shapeFaults e.path.toString)
  pure (files.size, faults)
