#!/bin/bash
# real-stills.sh [stills-dir]: LOCAL negative proofs on the audit's real stills (Rust t02/t37, Lean v3 t16; private evidence, not in the repo).
# Each still is looped into a 21.5 s take and run through vcheck with the still as its lossless frame. Asserts the checks that MUST fail on them
# (font-spacing 2.22 on all three; plot-legibility on the Rust t37 mosaic, with a hand-written sidecar since no recorder wrote one).
# T3, T2pre and box do NOT fail on these stills (their pitch is 28 and no pane edge is drawn early): their negative proofs are the synthetic
# fixtures in run.sh (bad-pitch24, bad-prediv). Not in CI: the stills are not in the repo. Missing stills = not_measured = exit 1.
set -u
HERE=$(cd "$(dirname "$0")" && pwd); S=${1:?usage: real-stills.sh <stills-dir>}
W=$(mktemp -d "${TMPDIR:-/tmp}/real-stills.XXXXXX"); export CORE_FPS=${CORE_FPS:-2}; bad=0; pass=0
for n in before-t02-code before-t37-plot lean-v3-t16; do [ -f "$S/$n.png" ] || { echo "not_measured: $S/$n.png missing"; exit 1; }
  ffmpeg -y -v error -loop 1 -framerate 20 -t 21.5 -i "$S/$n.png" -pix_fmt yuv420p -c:v libx264 -preset ultrafast -crf 14 -r 20 "$W/$n.mp4"; done
ck(){ local n=$1 want=$2; shift 2; local out; out=$("$HERE/../vcheck.sh" "$W/$n.mp4" "$@" 2>&1)
  for c in ${want//,/ }; do if echo "$out" | grep -q "^CHECK $c FAIL"; then pass=$((pass+1)); echo "ok   $n: $c FAIL"; else bad=$((bad+1)); echo "FAIL $n: $c did not FAIL"; echo "$out" | grep "CHECK $c" | cut -c1-200; fi; done; }
for n in before-t02-code before-t37-plot lean-v3-t16; do ck $n font-spacing --lossless "$S/$n.png" --shown 18.5; done
# t37: the plot axes box, hand-measured on the still (x 1340..1900, y 50..960); the fit is the red mosaic diagonal, the legend a 1 px-tall dash
. "$HERE/../lib.sh"
mk(){ { cat <<L
cell_w=20
cell_h=28
shown_s=0.0
plot_pane_left_px=1200
@RECTS@
rect.plot=1200,0,720,1080
rect.axes=1340,50,560,910
rect.title=1200,0,720,50
rect.legend=1200,980,720,100
rect.ticks=1200,950,720,40
fit_rgb=ff3b3b
axis_x=170,245
axis_x_data=170,245
axis_y=2000,7000
axis_y_data=2000,7000
tick_px=14
beats=
L
layout_rects 1200; } | grep -v "^@RECTS@" > "$1"; }
mk "$W/t37.layout"
# watermark vs rect.code: the rects lib.sh writes for the recorder (and gen.sh uses) must not overlap, and vcheck must see the
# watermark PASS and no watermark overlap, on all three real stills
for n in before-t02-code before-t37-plot lean-v3-t16; do mk "$W/$n.layout"; cp "$W/$n.mp4" "$W/w-$n.mp4"
  out=$("$HERE/../vcheck.sh" "$W/w-$n.mp4" "$W/$n.layout" --lossless "$S/$n.png" --shown 18.5 2>&1)
  if echo "$out" | grep -q '^CHECK watermark PASS' && ! echo "$out" | grep -q 'overlap(watermark,code)'; then pass=$((pass+1)); echo "ok   $n: watermark PASS, no overlap with rect.code"; else bad=$((bad+1)); echo "FAIL $n: watermark/rect.code"; echo "$out" | grep -i "watermark\|overlap" | cut -c1-200; fi; done
cp "$W/before-t37-plot.mp4" "$W/t37.mp4"; ck t37 plot-legibility "$W/t37.layout" --gate --lossless "$S/before-t37-plot.png"
echo "real stills: $pass ok, $bad wrong (local evidence, not CI); workdir $W"; [ $bad = 0 ]
