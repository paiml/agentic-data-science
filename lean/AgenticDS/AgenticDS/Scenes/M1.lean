/-
Copyright (c) 2026 Pragmatic AI Labs. All rights reserved.
Released under MIT license as described in the file LICENSE.
Authors: Pragmatic AI Labs
-/
import AgenticDS.Scenes.M1V01
import AgenticDS.Scenes.M1V02
import AgenticDS.Scenes.M1V03
import AgenticDS.Scenes.M1V04
import AgenticDS.Scenes.M1V05
import AgenticDS.Scenes.M1V06
import AgenticDS.Scenes.M1V07
import AgenticDS.Scenes.M1V08
import AgenticDS.Scenes.M1V09
import AgenticDS.Scenes.M1V10
import AgenticDS.Scenes.Run

/-! # Module 1 scenes: the id to scene table -/

def scenesM1 : List (String × IO Unit) := [
  ("v01", m1v01),
  ("v02", m1v02),
  ("v03", m1v03),
  ("v04", m1v04),
  ("v05", m1v05),
  ("v06", m1v06),
  ("v07", m1v07),
  ("v08", m1v08),
  ("v09", m1v09),
  ("v10", m1v10)]
