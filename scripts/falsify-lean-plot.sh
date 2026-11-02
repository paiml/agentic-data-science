#!/usr/bin/env bash
# Planted arms for lean-plot.sh check: a real plot passes; each missing part is refused (ADS-DEMO-001 R-6).
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
t="$(mktemp -d)"; trap 'rm -rf "${t:?}"' EXIT; pass=0; fail=0
good="$t/good.svg"
{ echo '<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080">'
  for i in 1 2 3 4 5 6; do echo "<path d=\"M0 $i L9 $i\"/>"; done
  for i in 1 2 3 4 5 6 7 8 9 10; do echo "<text x=\"$i\" y=\"1\">$i</text>"; done
  echo '<circle cx="1" cy="1" r="3"/><circle cx="2" cy="2" r="3"/></svg>'; } > "$good"
arm() { # name expect(pass|refuse) file
  out="$(scripts/lean-plot.sh check "$3" 2>&1)"; rc=$?
  if { [ "$2" = pass ] && [ "$rc" -eq 0 ]; } || { [ "$2" = refuse ] && [ "$rc" -ne 0 ]; }; then
    echo "  $1 ok"; pass=$((pass+1)); else echo "  $1 FAIL ($out)"; fail=$((fail+1)); fi; }
arm 00-control pass "$good"
: > "$t/empty.svg";                          arm 01-empty refuse "$t/empty.svg"
arm 02-missing refuse "$t/none.svg"
/usr/bin/grep -v '<circle' "$good" > "$t/nopts.svg"; echo '</svg>' >> "$t/nopts.svg"; arm 03-no-points refuse "$t/nopts.svg"
/usr/bin/grep -v '<path' "$good" > "$t/noaxes.svg";  arm 04-no-axes refuse "$t/noaxes.svg"
/usr/bin/grep -v '<text' "$good" > "$t/noticks.svg"; arm 05-no-ticks refuse "$t/noticks.svg"
echo "falsify-lean-plot: $pass passed, $fail failed"; [ "$fail" -eq 0 ]
