/-
Copyright (c) 2026 Pragmatic AI Labs. All rights reserved.
Released under MIT license as described in the file LICENSE.
Authors: Pragmatic AI Labs
-/
import AgenticDS.Scenes.Run
import AgenticDS.Scenes.M4V01
import AgenticDS.Scenes.M4V02
import AgenticDS.Scenes.M4V03
import AgenticDS.Scenes.M4V04
import AgenticDS.Scenes.M4V05
import AgenticDS.Scenes.M4V06
import AgenticDS.Scenes.M4V07
import AgenticDS.Scenes.M4V08
import AgenticDS.Scenes.M4V09
import AgenticDS.Scenes.M4V10

/-! # Module 4 scenes: the id to scene table -/

def scenesM4 : List (String × IO Unit) :=
  [("v01", m4v01), ("v02", m4v02), ("v03", m4v03),
   ("v04", m4v04), ("v05", m4v05), ("v06", m4v06),
   ("v07", m4v07), ("v08", m4v08), ("v09", m4v09),
   ("v10", m4v10)]
