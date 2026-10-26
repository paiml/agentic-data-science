#!/bin/bash
# regen-fixtures.sh: re-render fixtures/code14.png (14x34 cells, the ruled cell size), fixtures/code20.png (20x28, the old Rust/Lean size) and fixtures/code-pitch24.png (14x24: a sub-28 px line pitch, the T3 must-FAIL class)
# with the recorder's own renderer (termctrl), recoloured to the take background #1e1e1e and padded to 1920x1080. Needs termctrl + ImageMagick.
# The PNGs are committed so CI does not need termctrl.
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
for cfg in "14 34 137 31 code14" "20 28 96 38 code20" "14 24 137 44 code-pitch24"; do read -r w h c r n <<<"$cfg"
  termctrl save --cell-width $w --cell-height $h --padding 0 --pixel-ratio 1 --hide-cursor --cols $c --rows $r --out "/tmp/regen-${n:?}" --format png --pipe -- cat "$HERE/code.txt" >/dev/null
  convert "/tmp/regen-$n.png" -fuzz 1% -fill '#1e1e1e' -opaque '#0d1117' -background '#1e1e1e' -gravity NorthWest -extent 1920x1080 "$HERE/fixtures/$n.png"
  rm -f "/tmp/regen-${n:?}.png"
done
ls -l "$HERE/fixtures"
