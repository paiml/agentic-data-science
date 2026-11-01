import Anscombe
/-! Reads `$ADS_ROOT/data/anscombe/anscombe.csv`, prints the report
and, when `$ADS_OUT` is set, writes stdout.txt and plot.svg there.
Provable contract: all four sets share one summary. -/
open Anscombe

def main : IO UInt32 := do
  let root := (← IO.getEnv "ADS_ROOT").getD "../.."
  let csv ← IO.FS.readFile s!"{root}/data/anscombe/anscombe.csv"
  let sets ← IO.ofExcept (parse csv)
  let text := report sets
  IO.print text
  if let some dir := ← IO.getEnv "ADS_OUT" then
    IO.FS.writeFile s!"{dir}/stdout.txt" text
    IO.FS.writeFile s!"{dir}/plot.svg" (← IO.ofExcept (plotSvg sets))
  unless agree text do
    IO.eprintln "FAIL the quartet must agree"
    return 1
  IO.println "contract: ads-lean-anscombe-v1 four sets, one summary OK"
  return 0
