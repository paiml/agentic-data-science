/-
Copyright (c) 2026 Pragmatic AI Labs. All rights reserved.
Released under MIT license as described in the file LICENSE.
Authors: Pragmatic AI Labs
-/
import AgenticDS.Ols
import AgenticDS.OlsExample

/-! # OLS demo checks

Runtime checks on tiny exact data and the penguins fit. -/

open AgenticDS

def near (a b tol : ℚ) : Bool :=
  (if a < b then b - a else a - b) ≤ tol

def check (what : String) (ok : Bool) : IO Bool := do
  unless ok do IO.eprintln s!"FAIL {what}"
  pure ok

def main (args : List String) : IO UInt32 := do
  let root := args.headD "../.."
  let csv ← IO.FS.readFile s!"{root}/datasets/penguins/penguins.csv"
  let ps := pairsOf csv "flipper_length_mm" "body_mass_g"
  let f := fit ps
  let total := ((parseCsv csv).drop 1).length
  let rp ← readPairs root "flipper_length_mm" "body_mass_g"
  printTable ps f 1
  if ← System.FilePath.pathExists "plot.png" then
    IO.FS.removeFile "plot.png"
  demo [root]
  let mut passed := 0
  let mut ok := true
  let checks : List (String × Bool) := [
    ("342 rows after drop_na on the two model columns",
      ps.length == 342),
    ("2 rows dropped (NA in flipper or mass)",
      total - ps.length == 2),
    ("intercept = -5780.83 (tol 0.005)",
      near f.intercept (-578083 / 100) (1 / 200)),
    ("slope = 49.69 (tol 0.005)",
      near f.slope (4969 / 100) (1 / 200)),
    ("residuals sum to exactly 0", (residuals f ps).sum == 0),
    ("exact line y = 2x recovered, intercept 0",
      (fit [(1, 2), (2, 4), (3, 6)]).intercept == 0),
    ("exact line y = 1 + 2x recovered",
      (fit [(0, 1), (1, 3), (2, 5)]).intercept == 1),
    ("fmt2 rounds to two decimals",
      fmt2 (-5780.8271 : ℚ) == "-5780.83"),
    ("exact line y = 2x recovered",
      (fit [(1, 2), (2, 4), (3, 6)]).slope == 2),
    ("fmt2 rounds a tie up and keeps no -0.00",
      fmt2 (1 / 200) == "0.01" && fmt2 (-1 / 1000) == "0.00"),
    ("readPairs agrees with pairsOf", rp.length == ps.length),
    ("padL right-aligns", padL "7" 3 == "  7"),
    ("green and dimmed wrap ANSI codes",
      (green "x").length == 12 && (dimmed "x").length == 9),
    ("circle and label emit SVG",
      (circle 1 2).startsWith "<circle" &&
        (label 1 2 "end" "t").endsWith "</text>"),
    ("demo wrote the plot",
      (← System.FilePath.pathExists "plot.png") ||
        !(← haveConvert)),
    ("CAN_FAIL: NA row is dropped, not read as 0",
      (pairsOf "a,b\n1,2\nNA,3\n4,5\n" "a" "b").length == 2),
    ("an unknown column gives no pairs",
      (pairsOf "a,b\n1,2\n" "z" "b").isEmpty)]
  for (what, c) in checks do
    let r ← check what c
    if r then passed := passed + 1
    ok := ok && r
  if ok then
    IO.println s!"{passed} checks passed"
    IO.println "contract: ads-lean-p2-v1 OK"
    return 0
  else return 1
