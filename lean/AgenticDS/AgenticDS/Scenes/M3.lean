/-
Copyright (c) 2026 Pragmatic AI Labs. All rights reserved.
Released under MIT license as described in the file LICENSE.
Authors: Pragmatic AI Labs
-/
import AgenticDS.Scenes.Run
import AgenticDS.Scenes.M3V01
import AgenticDS.Scenes.M3V02
import AgenticDS.Scenes.M3V03
import AgenticDS.Scenes.M3V04
import AgenticDS.Scenes.M3V05
import AgenticDS.Scenes.M3V06
import AgenticDS.Scenes.M3V07
import AgenticDS.Scenes.M3V08
import AgenticDS.Scenes.M3V09
import AgenticDS.Scenes.M3V10

/-! # Module 3 scenes: the id to scene table -/

def scenesM3 : List (String × IO Unit) :=
  [("v01", m3v01), ("v02", m3v02), ("v03", m3v03),
   ("v04", m3v04), ("v05", m3v05), ("v06", m3v06),
   ("v07", m3v07), ("v08", m3v08), ("v09", m3v09),
   ("v10", m3v10)]
