#!/bin/bash
# gen.sh <outdir>: synthetic takes (1920x1080, 20 fps, 21.5 s: five 4.1 s beat windows, plot shown at 18.5 s, 3 s final hold) for run.sh.
# Needs ImageMagick, ffmpeg, DejaVu Sans Mono. Each take is the recipe of a real take class from the vcheck-rust-r3 / review r3 / review-82-r2 proof set,
# rebuilt from the real-renderer code fixtures (fixtures/*.png, termctrl) and a synthetic 720x1080 chart so the proofs run in CI without the private recordings.
# Every gate take carries what the recorder writes: <take>.layout (sidecar), <take>.layout.beats/ (beat snapshots), <take>.mp4.frame.png (lossless frame).
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../lib.sh"
O=${1:?outdir}; mkdir -p "$O"; cd "$O"
BG='#1e1e1e'; FONT=DejaVu-Sans-Mono; S=18.5
code(){ cp "$HERE/fixtures/$1.png" "$1.png"; }   # code14 = 14x34 cells (ruled), code20 = 20x28 (old), code-pitch24 = 14x24; rendered by termctrl, see regen-fixtures.sh
# dim: the lower two thirds of the lines at 38% of their contrast (the vimrc fade the Rust audit measured at ~30%)
mkdim(){ convert code14.png \( +clone -crop 1000x560+0+230 +repage -fill "$BG" -colorize 62% \) -geometry +0+230 -composite code-dim.png; }
plot(){ # name mode : 720x1080 chart, dark bg. title 28 pt at y>=72, legend (fit swatch + label) 26 pt, ticks 24 pt, axes box 50,175..690,1030
  local n=$1 m=$2 d=() cols=('#ff8c00' '#be50ff' '#00c8c8') fit='#ffd700' tp=28 lp=26 kp=24 ty=100 sw=3 line=1 leg=1
  case $m in white) fit='#ffffff';; gridfit) fit='#8c8c8c';; small) tp=16; lp=14; kp=12;; lowtitle) ty=50;; nolegend) leg=0;; nofit) line=0; leg=0;;
             markersonly) line=0; cols=('#ffd700' '#ffd700' '#ffd700');; thinfit|mosaic) fit='#7a1f1f'; sw=1;; esac
  while read -r x y c; do
    if [ "$m" = mosaic ]; then d+=(-fill "${cols[$c]}" -stroke none -draw "rectangle $((x/20*20)),$((y/20*20)) $((x/20*20+19)),$((y/20*20+19))")
    else d+=(-fill "${cols[$c]}" -stroke none -draw "circle $x,$y $((x+2)),$((y+2))"); fi
  done < <(awk 'BEGIN{srand(7); for(i=0;i<120;i++){ x=70+rand()*580; y=990-(x-70)*1.3+(rand()-0.5)*100; if(y<200)y=200; if(y>1010)y=1010; printf "%d %d %d\n",x,y,i%3 }}')
  [ $line = 1 ] && d+=(-stroke "$fit" -strokewidth $sw -draw "line 60,1000 660,220")
  d+=(-stroke '#808080' -strokewidth 1 -fill none -draw 'rectangle 50,175 690,1030')
  [ $leg = 1 ] && d+=(-stroke "$fit" -strokewidth $sw -draw "line 70,141 110,141")
  d+=(-stroke none -fill '#e0e0e0' -font $FONT -pointsize $tp -annotate +60+$ty 'Body mass vs flipper length')
  [ $leg = 1 ] && d+=(-pointsize $lp -annotate +120+150 'OLS fit')
  d+=(-pointsize $kp -annotate +50+1066 '170        200        235')
  convert -size 720x1080 xc:"$BG" "${d[@]}" "$1.png"; }
# take <name> <code png> <plot png> <overlay x> [pre filter] [final hold s] [head s] [post filter] : write name.mp4 (+ name.mp4.frame.png = the lossless code frame)
# A cursor blinks in an empty spot of the code pane until the reveal (a held screen is never bit-identical); CUR overrides its enable expression.
CUR=""
take(){ local n=$1 c=$2 p=$3 x=$4 pre=${5:-null} tail=${6:-3.0} head=${7:-$S} post=${8:-null}; local tot; tot=$(awk -v a=$head -v b=$tail 'BEGIN{print a+b}')
  local cur=${CUR:-"lt(t,$head)*lt(mod(t,2),1)"}
  while [ "$(jobs -r | wc -l)" -ge 12 ]; do wait -n; done   # encodes run in parallel (12 at a time); `wait` before a var copy
  ffmpeg -v error -y -framerate 20 -loop 1 -t $tot -i $c.png -framerate 20 -loop 1 -t $tot -i $p.png -filter_complex \
    "[0:v]${pre},drawbox=x=950:y=760:w=20:h=34:color=white:t=fill:enable='$cur'[b];[b][1:v]overlay=$x:0:enable='gte(t,$head)'[o];[o]${post}[q]" -map '[q]' -pix_fmt yuv420p -c:v libx264 -preset ultrafast -crf 14 -r 20 ${n}.mp4 &
  cp $c.png ${n}.mp4.frame.png; }
BEATS="cargo_toml,tree,version,call,stdout"
lay(){ # name plot_pane_left shown [extra lines...]  (a later line replaces an earlier key: vcheck takes the last occurrence)
  local n=$1 pl=$2 sh=$3; shift 3
  { echo "cell_w=14"; echo "cell_h=34"; echo "shown_s=$sh"; echo "plot_pane_left_px=$pl"; layout_rects "$pl"; echo "rect.plot=$pl,0,720,1080"   # rect.code + rect.watermark: lib.sh, as the recorder writes them
    echo "rect.axes=$((pl+52)),177,636,851"; echo "rect.title=$((pl+40)),64,600,56"; echo "rect.legend=$((pl+60)),124,300,44"
    echo "rect.ticks=$((pl+40)),1040,640,40"; echo "fit_rgb=ffd700"; echo "axis_x=170,235"; echo "axis_x_data=173,232"; echo "axis_y=2500,6500"
    echo "axis_y_data=2700,6300"; echo "tick_px=24"; echo "beats=$BEATS"; echo "beat.cargo_toml=0.5,4.6"; echo "beat.tree=4.6,8.7"; echo "beat.version=8.7,12.8"
    echo "beat.call=12.8,16.9"; echo "beat.stdout=16.9,21.0"; for l in "$@"; do echo "$l"; done; } > $n.layout; }
snaps(){ local d=$1.layout.beats; rm -rf $d; mkdir -p $d
  printf '[package]\nname = "ols"\n\n[dependencies]\npolars = "0.46"\naprender = "0.71.4"\naprender-viz = "0.71.4"\nserde_json = "1" # used by p2::golden (not ML)\n\n[dev-dependencies]\ntempfile = "3"\n' > $d/cargo_toml.txt
  printf 'aprender v0.71.4\n|-- trueno v0.9.0\n' > $d/tree.txt
  printf 'rustc 1.99.1 (abcdef 2026-06-01)\ncargo 1.99.1\n' > $d/version.txt
  printf 'let model = aprender::linear_model::LinearRegression::new();\n' > $d/call.txt
  printf 'slope = 49.69 g/mm   intercept = -5780.83 g\n' > $d/stdout.txt; }
gate(){ # name code plot x layoutpl [pre] [tail] [head] [post] [extra layout...] : a full gate take (video, frame, sidecar, snapshots)
  local n=$1 c=$2 p=$3 x=$4 pl=$5 pre=${6:-null} tail=${7:-3.0} head=${8:-$S} post=${9:-null}; shift 9 2>/dev/null || shift $#
  take $n $c $p $x "$pre" $tail $head "$post"; lay $n $pl $head "$@"; snaps $n; }
var(){ local n=$1 b=$2; cp $b.mp4 $n.mp4; cp $b.mp4.frame.png $n.mp4.frame.png; cp $b.layout $n.layout; rm -rf $n.layout.beats; cp -r $b.layout.beats $n.layout.beats; }
setk(){ { grep -v "^${2//./\\.}=" $1.layout || true; echo "$2=$3"; } > $1.tmp; mv $1.tmp $1.layout; }
code code14; code code20; code code-pitch24; mkdim
plot plot-native native; plot plot-white white; plot plot-mosaic mosaic; plot plot-thin thinfit; plot plot-nofit nofit; plot plot-gridfit gridfit
plot plot-small small; plot plot-lowtitle lowtitle; plot plot-nolegend nolegend; plot plot-markers markersonly
E="enable='gte(t,$S)'"; EP="enable='lt(t,$S)'"
# --- good
gate good-v3 code14 plot-native 1200 1200
gate good-x1100 code14 plot-native 1100 1100 null 3.0 $S null
gate good-white code14 plot-white 1200 1200 null 3.0 $S null "fit_rgb=ffffff"
wait; var good-beats good-v3
# --- font-spacing / plot-legibility bad (Rust t02/t37 class: old cell size, half-block mosaic, 1 px dark fit)
gate bad-oldfont code20 plot-native 1200 1200
gate bad-mosaic code14 plot-mosaic 1200 1200
gate bad-fit1px code14 plot-thin 1200 1200
gate bad-axis50 code14 plot-native 1200 1200 null 3.0 $S null "axis_x_data=190,215"
wait; var bad-axis150 good-v3; setk bad-axis150 axis_x_data 150,250
gate bad-overlap code14 plot-native 1200 1200 null 3.0 $S null "rect.watermark=900,100,180,40"
gate bad-nofit-white code14 plot-nofit 1200 1200 null 3.0 $S null "fit_rgb=ffffff"
gate bad-fit-grid code14 plot-gridfit 1200 1200 null 3.0 $S null "fit_rgb=8c8c8c"
gate bad-fit-bg code14 plot-nofit 1200 1200 null 3.0 $S null "fit_rgb=2a2a2a"
gate bad-markers code14 plot-markers 1200 1200
# --- plot-text / watermark / cell / lossless / dim / reveal / fade
gate bad-smalltext code14 plot-small 1200 1200 null 3.0 $S null "tick_px=24"
gate bad-lowtitle code14 plot-lowtitle 1200 1200
gate bad-nolegend code14 plot-nolegend 1200 1200
var bad-ticks14 good-v3; setk bad-ticks14 tick_px 14
var bad-wm-bl good-v3; setk bad-wm-bl rect.watermark 60,1000,180,40
var bad-wm-code good-v3; setk bad-wm-code rect.watermark 600,16,200,40            # over the code pane band
var bad-wm-low good-v3; setk bad-wm-low rect.watermark 1700,100,200,40               # top-right but below y=72 (on the plot title)
var bad-nocell good-v3; setk bad-nocell cell_w 20; setk bad-nocell cell_h 28
var bad-nolossless good-v3; rm -f bad-nolossless.mp4.frame.png
gate bad-dim code-dim plot-native 1200 1200
gate bad-revealshift code14 plot-native 1200 1200 "pad=1940:1080:0:0:0x1e1e1e,crop=1920:1080:'if(gte(t,$S),20,0)':0"
gate bad-fade code14 plot-native 1200 1200 null 3.0 $S "fade=t=out:st=18.6:d=0.2"
# --- pixel classes: line pitch < 28 (T3), divider before the plot (T2pre) with an empty margin (box)
gate bad-pitch24 code-pitch24 plot-native 1200 1200 null 3.0 $S null "cell_h=24"
gate bad-prediv code14 plot-native 1150 1150 "drawbox=x=1150:y=0:w=1:h=1080:color=0x333333:t=fill:$EP"
# --- pane-edge classes (shifted plot, review r3 n7/o3, pixel-only o1 o2 o5 o6)
gate bad-shift900 code14 plot-native 900 900
gate bad-n7 code14 plot-native 1150 860
gate bad-o3-border3 code14 plot-native 1100 922 "drawbox=x=922:y=0:w=998:h=1080:color=0x1E1E1E:t=fill:$E,drawbox=x=922:y=0:w=1:h=1080:color=0x212121:t=fill:$E"
for c in "o1-step4 0x222222" "o2-hue 0x211E1B"; do read -r nm col <<<"$c"; take bad-$nm code14 plot-native 1150 "drawbox=x=860:y=0:w=1060:h=1080:color=$col:t=fill:$E"; done
take bad-o5-div1 code14 plot-native 1150 "drawbox=x=860:y=0:w=1060:h=1080:color=0x1E1E1E:t=fill:$E,drawbox=x=860:y=0:w=1:h=1080:color=0x333333:t=fill:$E"
take bad-o6-div2 code14 plot-native 1150 "drawbox=x=860:y=0:w=1060:h=1080:color=0x1E1E1E:t=fill:$E,drawbox=x=860:y=0:w=2:h=1080:color=0x363636:t=fill:$E"
take bad-gutter50 code14 plot-native 962 "drawbox=x=962:y=0:w=958:h=1080:color=0x262626:t=fill:$E"
# --- frozen frames
CUR="lt(t,$S)*lt(mod(t,2),1)*not(between(t,6,11))" gate bad-freeze code14 plot-native 1200 1200
wait; setk bad-freeze beats ""     # a 5 s still (6..11 s) with no beat window declared over it: a still stretch outside the beats
gate bad-shorthold code14 plot-native 1200 1200 null 1.0
gate bad-nohold code14 plot-native 1200 1200 null 0.3
wait; ffmpeg -v error -y -i good-v3.mp4 -vf scale=1280:720 -c:v libx264 -crf 14 bad-fmt.mp4; cp good-v3.layout bad-fmt.layout; cp good-v3.mp4.frame.png bad-fmt.mp4.frame.png; cp -r good-v3.layout.beats bad-fmt.layout.beats
# --- beats (measured on the snapshots and the frames; review-82-r2 items 1, 8, 12)
var bad-beats good-v3; sed -i 's/ # used by p2::golden (not ML)//' bad-beats.layout.beats/cargo_toml.txt                       # serde_json unexplained (the real Rust pilot's fourth crate)
var bad-beats-aviz good-v3; printf '[dependencies]\npolars = "0.46"\naprender-viz = "0.71.4"\n\n[dev-dependencies]\naprender = "0.71.4"\n' > bad-beats-aviz.layout.beats/cargo_toml.txt
var bad-beats-table good-v3; printf '[dependencies]\naprender = "0.71.4"\n\n[dependencies.serde_json]\nversion = "1"\n' > bad-beats-table.layout.beats/cargo_toml.txt
var bad-beats-tree good-v3; printf 'aprender-viz v0.71.4\n' > bad-beats-tree.layout.beats/tree.txt
var bad-beats-version good-v3; printf 'hello\n' > bad-beats-version.layout.beats/version.txt
var bad-beats-call good-v3; printf 'let model = p2::fit();\n' > bad-beats-call.layout.beats/call.txt
var bad-beats-unit good-v3; printf 'slope = 49.69   intercept = -5780.83\n' > bad-beats-unit.layout.beats/stdout.txt
var bad-beats-subset good-v3; setk bad-beats-subset beats version
var bad-beats-nokey good-v3; { grep -v '^beats=' good-v3.layout || true; } > bad-beats-nokey.layout
var bad-beats-short good-v3; setk bad-beats-short beat.tree 4.6,7.6
var bad-beats-outside good-v3; setk bad-beats-outside beat.stdout 19.0,23.5
var bad-beats-overlap good-v3; setk bad-beats-overlap beat.tree 4.0,8.7
var bad-beats-long good-v3; setk bad-beats-long beat.stdout 11.5,21.0                       # a 9.5 s window would exempt a 9.5 s freeze from `frozen` (cap 8 s)
var bad-beats-use good-v3; printf 'use aprender::prelude::*;\n' > bad-beats-use.layout.beats/call.txt   # an import is not a call
var bad-beats-build good-v3; printf '   Compiling demo v0.1.0\n    Finished dev profile in 0.42s\n' > bad-beats-build.layout.beats/stdout.txt   # build chatter is not program output
gate bad-beats-moving code14 plot-native 1200 1200 "drawbox=x=0:y=0:w=980:h=800:color=0x1E1E1E:t=fill:enable='between(t,6,18)'"
wait; echo "gen done: $(ls *.mp4 | wc -l) takes"
# --- beats vs frozen: the real recorder hides the cursor, so a held beat is bit-identical. A real take must pass both.
CUR=0 gate good-real code14 plot-native 1200 1200                                           # no blinking cursor: whole beats are still frames
CUR=0 gate bad-still-outside code14 plot-native 1200 1200 null 3.0 26 null                  # still 21.0..26.0 s lies outside every declared beat window (5 s > 3.5 s)
wait; var bad-real-short good-real; setk bad-real-short beat.tree 4.6,7.6                  # a beat held 3 s < 4 s
# --- core failure and sidecar-only without a layout
printf 'not a video\n' > bad-garbage.mp4
