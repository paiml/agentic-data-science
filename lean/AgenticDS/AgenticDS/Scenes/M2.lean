/-
Copyright (c) 2026 Pragmatic AI Labs. All rights reserved.
Released under MIT license as described in the file LICENSE.
Authors: Pragmatic AI Labs
-/
import AgenticDS.Scenes.M2V01
import AgenticDS.Scenes.M2V02
import AgenticDS.Scenes.M2V03
import AgenticDS.Scenes.M2V06
import AgenticDS.Scenes.M2V07
import AgenticDS.Scenes.M2V08
import AgenticDS.Scenes.M2V10

/-! # Module 2 scenes: the id to scene table. Scenes 4, 5 and 9
run in the terminal as plain `lake env lean FILE`; they stay out
of the library so `lake build` has no stored output to replay. -/

def scenesM2 : List (String × IO Unit) :=
  [("v01", m2v01), ("v02", m2v02), ("v03", m2v03),
   ("v04", pure ()), ("v05", pure ()), ("v06", m2v06),
   ("v07", m2v07), ("v08", m2v08), ("v09", pure ()),
   ("v10", m2v10)]
