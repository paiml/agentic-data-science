#!/usr/bin/env bash
# Falsifier for plot_scatter_source on the m3 penguin scatters. For each of v05, v08, v09 the demo's own
# penguinDemo call (read from AgenticDS/Examples/M3Vxx.lean) is run through a copy of Examples/Scat.lean whose
# plotted points are planted wrong; writeScatter must refuse it with "plot_scatter_source violated".
# Four plants per id: a shifted point, a missing point, an extra point, swapped axes. The unplanted copy must pass.
# Run from lean/AgenticDS.
set -uo pipefail
export PATH="$HOME/.elan/bin:$PATH"
LEANOPTS=(-DwarningAsError=true -Dweak.linter.mathlibStandardSet=true -Dweak.linter.style.longLine.maxLineLength=200)
T=$(mktemp -d); trap 'rm -rf "${T:?}"' EXIT
fail=0; arms=0
HELP='def pShift (l : List (Float × Float)) :=
  l.mapIdx fun i p => if i == 0 then (p.1 + 1, p.2) else p
def pMissing (l : List (Float × Float)) := l.drop 1
def pExtra (l : List (Float × Float)) := l ++ [(0, 0)]'
shape='(d.map fun p => (qf p.1, qf p.2))'
for id in v05 v08 v09; do
  call=$(awk '/^  penguinDemo /{p=1} p{print; if ($0 ~ /[0-9]+$/) exit}' "AgenticDS/Examples/M3${id^^}.lean")
  [ -n "$call" ] || { echo "FAIL $id: no penguinDemo call"; fail=1; continue; }
  for plant in none shift missing extra swap; do
    case "$plant" in
      none) rep="$shape" ;;
      shift) rep='(pShift (d.map fun p => (qf p.1, qf p.2)))' ;;
      missing) rep='(pMissing (d.map fun p => (qf p.1, qf p.2)))' ;;
      extra) rep='(pExtra (d.map fun p => (qf p.1, qf p.2)))' ;;
      swap) rep='(d.map fun p => (qf p.2, qf p.1))' ;;
    esac
    f="$T/P_${id}_$plant.lean"
    # Scat.lean with the plotted points replaced; its source rows stay the raw CSV.
    awk -v rep="$rep" -v shape="$shape" '{ i = index($0, shape); if (i) $0 = substr($0, 1, i-1) rep substr($0, i+length(shape)); print }' \
      AgenticDS/Examples/Scat.lean > "$f"
    awk -v h="$HELP" '{print} /^open AgenticDS/{print h}' "$f" > "$f.2" && mv "$f.2" "$f"
    grep -qF -- "$rep" "$f" || { echo "FAIL $id/$plant: plant did not apply"; fail=1; continue; }
    printf '\ndef main : IO UInt32 := do\n%s\n  pure 0\n' "$call" >> "$f"
    arms=$((arms+1))
    if o=$(lake env lean "${LEANOPTS[@]}" --run "$f" 2>&1); then rc=0; else rc=1; fi
    if [ "$plant" = none ]; then
      { [ "$rc" -eq 0 ] && echo "$o" | grep -q 'contract: plot_scatter_source OK'; } && echo "arm $id/none ok" || { echo "FAIL $id/none: honest run refused: $o"; fail=1; }
    else
      { [ "$rc" -ne 0 ] && echo "$o" | grep -q 'plot_scatter_source violated'; } && echo "arm $id/$plant refused" || { echo "FAIL $id/$plant: not refused as plot_scatter_source: $o"; fail=1; }
    fi
  done
done
rm -f plot-m3v05.svg plot-m3v08b.svg plot-m3v09.svg 2>/dev/null
[ "$fail" -eq 0 ] && echo "falsifier OK ($arms arms)"
exit "$fail"
