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
  out="$(${LP:-scripts/lean-plot.sh} check "$3" 2>&1)"; rc=$?
  if { [ "$2" = pass ] && [ "$rc" -eq 0 ]; } || { [ "$2" = refuse ] && [ "$rc" -ne 0 ]; }; then
    echo "  $1 ok"; pass=$((pass+1)); else echo "  $1 FAIL ($out)"; fail=$((fail+1)); fi; }
arm 00-control pass "$good"
: > "$t/empty.svg";                          arm 01-empty refuse "$t/empty.svg"
arm 02-missing refuse "$t/none.svg"
/usr/bin/grep -v '<circle' "$good" > "$t/nopts.svg"; echo '</svg>' >> "$t/nopts.svg"; arm 03-no-points refuse "$t/nopts.svg"
/usr/bin/grep -v '<path' "$good" > "$t/noaxes.svg";  arm 04-no-axes refuse "$t/noaxes.svg"
/usr/bin/grep -v '<text' "$good" > "$t/noticks.svg"; arm 05-no-ticks refuse "$t/noticks.svg"
# bar charts (ads#153): bars count as marks, the background rect does not
bars() { # n -> nopts.svg with n bar rects and the full-canvas background rect
  { /usr/bin/grep -v '</svg>' "$t/nopts.svg"; echo '<rect width="1920" height="1080"/>'
    for i in $(seq 1 "$1"); do echo "<rect x=\"$i\" y=\"1\" width=\"5\" height=\"9\"/>"; done; echo '</svg>'; }; }
bars 3 > "$t/bars3.svg"; arm 15-bars-ok pass "$t/bars3.svg"
bars 1 > "$t/bars1.svg"; arm 16-one-bar refuse "$t/bars1.svg"
bars 0 > "$t/bars0.svg"; arm 17-background-rect-only refuse "$t/bars0.svg"
/usr/bin/grep -v '<path' "$t/bars3.svg" > "$t/barsnoaxes.svg"; arm 18-bars-no-axes refuse "$t/barsnoaxes.svg"
# usage errors and the png/clip modes, with stub lake and rmedia so the arms are hermetic
want() { # name expected-rc cmd...
  n="$1"; e="$2"; shift 2; "$@" >"$t/o.txt" 2>&1; rc=$?
  if [ "$rc" -eq "$e" ]; then echo "  $n ok"; pass=$((pass+1)); else echo "  $n FAIL (rc=$rc want $e)"; fail=$((fail+1)); fi; }
S=${LP:-scripts/lean-plot.sh}
want 06-no-mode 2 $S
want 07-bad-mode 2 $S nope
want 08-bad-example 2 $S png m9 v99 "$t/o"
mkdir "$t/bin"
printf '#!/bin/sh\n[ "$STUB" = nolake ] && exit 0\ncp "%s" "plot-$(echo "$2" | cut -d- -f2)$3.svg"\n' "$good" > "$t/bin/lake"
printf '#!/bin/sh\ncase "$1" in svg2png) [ "$STUB" = nopng ] || echo png > "$3";; animate) [ "$STUB" = noclip ] || { for a; do o="$a"; done; echo mp4 > "$o"; };; esac\n' > "$t/bin/rmstub"
chmod +x "$t/bin/lake" "$t/bin/rmstub"
export RMEDIA="$t/bin/rmstub" PATH="$t/bin:$PATH"
want 09-png-ok 0 $S png m1 v01 "$t/o"
STUB=nolake want 10-png-no-svg 1 $S png m1 v01 "$t/o"
STUB=nopng want 11-png-no-file 1 $S png m1 v01 "$t/o2"
want 12-clip-ok 0 $S clip "$good" 2 "$t/c.mp4"
want 13-clip-bad-plot 1 $S clip "$t/nopts.svg" 2 "$t/c2.mp4"
STUB=noclip want 14-clip-no-file 1 $S clip "$good" 2 "$t/c3.mp4"
rm -f lean/AgenticDS/plot-m1v01.svg
echo "falsify-lean-plot: $pass passed, $fail failed"; [ "$fail" -eq 0 ]
