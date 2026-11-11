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

/-! # Scene set 3: the id to scene table -/

def scenesM3 : List (String × IO Unit) :=
  [("v01", s3v01), ("v02", s3v02), ("v03", s3v03),
   ("v04", s3v04), ("v05", s3v05), ("v06", s3v06),
   ("v07", s3v07), ("v08", s3v08), ("v09", s3v09),
   ("v10", s3v10)]
