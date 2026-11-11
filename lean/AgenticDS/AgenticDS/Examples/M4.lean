/-
Copyright (c) 2026 Pragmatic AI Labs. All rights reserved.
Released under MIT license as described in the file LICENSE.
Authors: Pragmatic AI Labs
-/
import AgenticDS.Examples.Run
import AgenticDS.Examples.M4V01
import AgenticDS.Examples.M4V02
import AgenticDS.Examples.M4V03
import AgenticDS.Examples.M4V04
import AgenticDS.Examples.M4V05
import AgenticDS.Examples.M4V06
import AgenticDS.Examples.M4V07
import AgenticDS.Examples.M4V08
import AgenticDS.Examples.M4V09
import AgenticDS.Examples.M4V10

/-! # Module 4 examples: the id to example table -/

def examplesM4 : List (String × IO Unit) :=
  [("v01", m4v01), ("v02", m4v02), ("v03", m4v03),
   ("v04", m4v04), ("v05", m4v05), ("v06", m4v06),
   ("v07", m4v07), ("v08", m4v08), ("v09", m4v09),
   ("v10", m4v10)]
