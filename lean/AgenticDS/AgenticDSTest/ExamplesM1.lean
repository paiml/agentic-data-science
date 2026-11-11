/-
Copyright (c) 2026 Pragmatic AI Labs. All rights reserved.
Released under MIT license as described in the file LICENSE.
Authors: Pragmatic AI Labs
-/
import AgenticDS.Examples.M1
import AgenticDS.Examples.M1Data

/-! Module 1 example checks: registry, values, every example
runs. -/

open AgenticDS

-- Lines each example must print.
def m1Want : List (String × List String) := [
  ("v01", ["mean     = 5", "variance = 4",
    "svg 8 points plot-m1v01.svg",
    "contract: plot_scatter_bounded OK"]),
  ("v02", ["(1/3 + 1/3 + 1/3 : ℚ) = 1",
    "exact sum of 342 bills = 150213/10",
    "svg 342 points plot-m1v02.svg"]),
  ("v03", ["leanprover/lean4:v4.35.0", "lean-toolchain: 1 lines",
    "svg 3 points plot-m1v03.svg",
    "contract: plot_scatter_bounded OK"]),
  ("v04", [", 0 markers", " points plot-m1v04.svg",
    "contract: plot_scatter_bounded OK"]),
  ("v05", ["n = 151, variance = 4762907500/22801 g^2",
    "variance >= 0: true", "shift leaves variance unchanged: true",
    "svg 11 points plot-m1v05.svg"]),
  ("v06", ["contract: ads-lean-p1-v1 OK",
    "12 means, worst gap 0.000000", "all 12 means agree with R",
    "svg 12 points plot-m1v06.svg"]),
  ("v07", ["AgenticDS.variance_nonneg depends on axioms: [",
    "AgenticDS.variance_shift depends on axioms: [",
    "AgenticDS.mean_const depends on axioms: [",
    "svg 3 points plot-m1v07.svg"]),
  ("v08", ["FALSIFY lines: 1", "45 lines in the contract file",
    "svg 45 points plot-m1v08.svg"]),
  ("v09", ["check build: ", "check scan: 0 items",
    "check axioms: 12 items", "check golden: 12 items",
    "svg 4 points plot-m1v09.svg"]),
  ("v10", ["Adelie: n = 151, mean = 558800/151 g",
    "Chinstrap: n = 68, mean = 126925/34 g",
    "Gentoo: n = 123, mean = 624350/123 g",
    "svg 342 points plot-m1v10.svg"])]

-- Red marks each plot adds on top of its points.
def m1Marks : List (String × Nat) := [("v10", 3)]

def has (o s : String) : Bool := (o.splitOn s).length > 1

-- The plot an example printed: its file holds one circle per
-- point and mark, a title, axis text and a closed svg.
def checkPlot (id out : String) : IO Bool := do
  let some l := (out.splitOn "\n").find? (·.startsWith "svg ")
    | IO.eprintln s!"FAIL {id} printed no svg line"; pure false
  match l.splitOn " " with
  | [_, n, _, path] =>
    let svg ← IO.FS.readFile path
    let want := n.toNat?.getD 0 + (m1Marks.lookup id).getD 0
    let c := (svg.splitOn "<circle").length - 1
    let okC := c == want && want > 0
    let okS := has svg "<svg" && has svg "</svg>" &&
      has svg "<title" && has svg "<path" &&
      has out "contract: plot_scatter_bounded OK"
    unless okC && okS do
      IO.eprintln s!"FAIL {id} plot {path}: {c} circles"
    pure (okC && okS)
  | _ => IO.eprintln s!"FAIL {id} svg line {l}"; pure false

-- Text no example may print.
def m1Ban : List (String × List String) := [
  ("v07", ["sorryAx", "axioms: []"])]

def main (_ : List String) : IO UInt32 := do
  let mut ok := true
  let dir : System.FilePath := "AgenticDS/Examples"
  let files := ((← dir.readDir).filter
    fun e => e.fileName.startsWith "M1V").size
  if files != examplesM1.length then
    IO.eprintln s!"FAIL {files} files, {examplesM1.length} examples"
    ok := false
  if mean m1v01_xs != 5 || variance m1v01_xs != 4 then
    IO.eprintln "FAIL mean/variance of the example data"
    ok := false
  if m1v02_third != 1 || m1v02_float != false then
    IO.eprintln "FAIL exact rationals against Float"
    ok := false
  if (← m1v03_pin) != "leanprover/lean4:v4.35.0\n" then
    IO.eprintln "FAIL toolchain pin"
    ok := false
  -- The gate scan must see a banned word and pass clean text.
  if hits ("so" ++ "rry") != 1 || hits "clean" != 0 then
    IO.eprintln "FAIL the scan misses or invents a marker"
    ok := false
  if (goldMean (Lean.Json.mkObj []) "Adelie" "x").isSome then
    IO.eprintln "FAIL gold read from nothing"
    ok := false
  for (id, act) in examplesM1 do
    try
      let (out, _) ← IO.FS.withIsolatedStreams act
      for w in (m1Want.lookup id).getD [] do
        unless (out.splitOn w).length > 1 do
          IO.eprintln s!"FAIL {id} lacks {w}"; ok := false
      for w in (m1Ban.lookup id).getD [] do
        if (out.splitOn w).length > 1 then
          IO.eprintln s!"FAIL {id} prints {w}"; ok := false
      unless (← checkPlot id out) do ok := false
    catch e => IO.eprintln s!"FAIL {id}: {e}"; ok := false
  if ok then IO.println "contract: ads-lean-examples-m1-v1 OK"
  pure (if ok then 0 else 1)
