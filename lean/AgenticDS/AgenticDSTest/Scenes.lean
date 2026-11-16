/-
Copyright (c) 2026 Pragmatic AI Labs. All rights reserved.
Released under MIT license as described in the file LICENSE.
Authors: Pragmatic AI Labs
-/
import AgenticDS.Scenes.M1
import AgenticDS.Scenes.M2
import AgenticDS.Scenes.M3
import AgenticDS.Scenes.M4
import AgenticDS.Scenes.M2V09

/-! Scene checks: each set's registry matches its files, every
file keeps the 25 x 59 shape, every scene runs, and the one
scene that shows a refusal refuses with its own message. -/

open AgenticDS

/-- Scenes that must refuse, with the message they refuse with. -/
def sceneRefusals : List (String × String) :=
  [("s3/v09", "confusion differs")]

/-- Check one scene set; `true` when it has no fault. -/
def checkSet (m : Nat) (scenes : List (String × IO Unit)) :
    IO Bool := do
  let (files, faults) ← moduleShape m
  let mut ok := faults.isEmpty
  for f in faults do IO.eprintln s!"FAIL {f}"
  if files != scenes.length then
    IO.eprintln
      s!"FAIL set {m}: {files} files, {scenes.length} scenes"
    ok := false
  for (id, act) in scenes do
    let key := s!"s{m}/{id}"
    match sceneRefusals.lookup key, ← (act.toBaseIO) with
    | none, .ok _ => pure ()
    | some want, .error e =>
      unless (toString e) == want do
        IO.eprintln s!"FAIL {key} refused with {e}, not {want}"
        ok := false
    | none, .error e =>
      IO.eprintln s!"FAIL {key}: {e}"; ok := false
    | some want, .ok _ =>
      IO.eprintln s!"FAIL {key} ran, but must refuse: {want}"
      ok := false
  pure ok

def main (_ : List String) : IO UInt32 := do
  let mut ok := true
  for (m, scenes) in [(1, scenesM1), (2, scenesM2), (3, scenesM3),
      (4, scenesM4)] do
    ok := (← checkSet m scenes) && ok
  -- Data the scenes show on screen and prove things about.
  unless s2v03_d.length == 3 && olsSlope s2v09_data == 5 / 2 do
    IO.eprintln "FAIL scene data"; ok := false
  unless s3v01_files == ["Kmeans", "Confusion", "Tree"] do
    IO.eprintln "FAIL s3v01_files"; ok := false
  if ok then IO.println "contract: ads-lean-scenes-v1 OK"
  pure (if ok then 0 else 1)
