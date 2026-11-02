#!/usr/bin/env bash
# Lean demo plot (ADS-DEMO-001 R-6, D-4): run one Lean example, check its SVG is a real plot
# (axes, grid, tick labels, and points or bars), rasterise it with rmedia (resvg) and hold it as a clip.
# usage: lean-plot.sh check <svg>                    RED unless the SVG is a plot with axes, ticks and points
#        lean-plot.sh png <m1..m4> <v01..v10> <out>  run the example, check, write <out>/plot-<m><v>.png
#        lean-plot.sh clip <svg> <secs> <out.mp4>    check, then render the plot as a held clip (rmedia animate)
set -euo pipefail
RM="${RMEDIA:-rmedia}"
count() { { /usr/bin/grep -o "$1" "$2" || true; } | wc -l; }
check() {
  [ -s "$1" ] || { echo "FAIL: $1 missing or empty"; return 1; }
  [ "$(( $(count '<circle' "$1") + $(count '<rect x=' "$1") ))" -ge 2 ] || { echo "FAIL: $1 has fewer than 2 points or bars"; return 1; }
  [ "$(count '<path' "$1")" -ge 4 ] || { echo "FAIL: $1 has no axes and gridlines"; return 1; }
  [ "$(count '<text' "$1")" -ge 8 ] || { echo "FAIL: $1 has no tick labels, title or axis labels"; return 1; }
  echo "plot OK: $1"
}
mode="${1:-}"
case "$mode" in
  check) check "$2";;
  png)
    m="$2"; v="$3"; out="$4"; root="$(cd "$(dirname "$0")/../lean/AgenticDS" && pwd)"
    case "$m$v" in m[1-4]v[01][0-9]) ;; *) echo "usage: lean-plot.sh png m1..m4 v01..v10 <out>"; exit 2;; esac
    mkdir -p "$out"; svg="$root/plot-$m$v.svg"; rm -f "${svg:?}"
    (cd "$root" && lake exe "example-$m" "$v" >/dev/null)
    check "$svg"; "$RM" svg2png "$svg" "$out/plot-$m$v.png"
    [ -s "$out/plot-$m$v.png" ] || { echo "FAIL: no png written"; exit 1; }
    echo "png OK: $out/plot-$m$v.png";;
  clip)
    svg="$2"; secs="$3"; out="$4"; check "$svg"
    t="$(mktemp -d)"; trap 'rm -rf "${t:?}"' EXIT; cp "$svg" "$t/Frame-0.svg"
    "$RM" animate --frames "$t/Frame-*.svg" --duration "$secs" --fps 20 -q -o "$out"
    [ -s "$out" ] || { echo "FAIL: no clip written"; exit 1; }
    echo "clip OK: $out";;
  *) echo "usage: lean-plot.sh check|png|clip"; exit 2;;
esac
