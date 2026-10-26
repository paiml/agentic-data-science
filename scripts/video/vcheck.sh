#!/bin/bash
# vcheck.sh <video 1920x1080 20fps> [layout.sidecar] [--gate] [--lossless frame.png] [--shown S] [--sidecar-only]
# One verdict for a recorded take: input, the recorder's layout sidecar, the pixel core (T3 line pitch, T2pre, box, T2post plot edge),
# pane-edge, cell, font-spacing, dim-luma, reveal-shift, plot-legibility, plot-text, watermark, hold-fade, beats, frozen frames.
# Prints "CHECK <name> PASS|FAIL|N/A detail" lines and "VERDICT PASS|FAIL"; exit 1 on FAIL. N/A only without --gate/--sidecar-only, for a check whose
# input is absent; under --gate an unmeasurable check is FAIL, never N/A.
# --gate: the take is a gate take: a missing sidecar, a missing/empty required sidecar field, a missing lossless frame or missing beats are
# not_measured = FAIL (pre-sidecar takes stay pixel-only in plain mode; that limit is stated as N/A).
# Layout sidecar (last occurrence of a key wins): key=value lines written by scripts/video/lib.sh and compose.sh (see README.md).
# Thresholds are the fixed font and plot limits. The sidecar only says WHERE things are (rects) and what the recorder
# intended (fit colour, beat windows); every verdict number is measured on the frames or on the beat snapshots.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/cell.env"
v=${1:?usage: vcheck.sh video [layout] [--gate] [--sidecar-only] [--lossless png] [--shown S]}; shift
layout=""; gate=0; lossless=""; shown=""; sidecar_only=0
[ $# -gt 0 ] && [ "${1#--}" = "$1" ] && { layout=$1; shift; }
while [ $# -gt 0 ]; do case $1 in --gate) gate=1;; --lossless) lossless=$2; shift;; --shown) shown=$2; shift;; --sidecar-only) sidecar_only=1;; *) echo "bad arg $1"; exit 2;; esac; shift; done
tmp=$(mktemp -d "${TMPDIR:-/tmp}/vcheck.XXXXXX"); trap 'rm -rf "${tmp:?}"' EXIT
for h in glyph plot text diffwin; do gcc -O2 -o "$tmp/$h" "$HERE/$h.c" -lm || { echo "helper build failed: $h"; exit 2; }; done
fails=0
res(){ echo "CHECK $1 $2 $3"; [ "$2" = FAIL ] && fails=$((fails+1)); return 0; }
lk(){ local k=${1//./\\.}; [ -n "$layout" ] && [ -f "$layout" ] && sed -n "s/^$k=//p" "$layout" | tail -1; }
[ -n "$layout" ] && [ ! -f "$layout" ] && layout=""
[ -z "$shown" ] && shown=$(lk shown_s); shown=${shown:-99999}
num='[0-9]+(\.[0-9]+)?'   # a plain decimal: '.', '1.2.3' and '' are not numbers
[[ $shown =~ ^$num$ ]] || shown=99999
dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$v")
# --- input format: 1920x1080 at 20 fps with at least one frame; anything else is not measurable (FAIL, never a vacuous pass)
geo=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height,r_frame_rate -of csv=p=0 "$v" 2>/dev/null | head -1)
case $dur in ''|*[!0-9.]*|.|*.*.*) dur=0;; esac   # N/A or garbage duration is not a duration
if [ "$geo" = "1920,1080,20/1" ] && awk -v d="$dur" 'BEGIN{exit !(d>0.5)}'; then res input PASS "$geo ${dur}s"
else res input FAIL "need 1920,1080,20/1 and a non-empty take, got '${geo:-none}' ${dur:-0}s"; fi
inrect(){ [[ $1 =~ ^[0-9]+,[0-9]+,[0-9]+,[0-9]+$ ]] && echo "${1//,/ }" || echo "0 0 0 0"; }   # a malformed rect is FAILed by the sidecar check; never feed it to ffmpeg/arithmetic
# crop <out.raw> <rect "x,y,w,h"> <time> <rgb24|gray>: one raw frame of a rect of the take
crop(){ local x y w h; read -r x y w h <<<"$(inrect "$2")"; ffmpeg -v error -y -ss "$3" -i "$v" -frames:v 1 -vf "crop=$w:$h:$x:$y,format=$4" -f rawvideo "$1"; }
# --- gate mode: every sidecar field a check needs must be present and non-empty, else the take is not measured = FAIL
if [ -z "$layout" ] && { [ $gate = 1 ] || [ $sidecar_only = 1 ]; }; then res sidecar FAIL "no layout sidecar (missing file or none given: not_measured)"
elif [ $gate = 1 ] || [ $sidecar_only = 1 ]; then miss=""
  for k in cell_w cell_h shown_s plot_pane_left_px rect.code rect.plot rect.axes rect.title rect.legend rect.ticks rect.watermark fit_rgb axis_x axis_x_data axis_y axis_y_data tick_px beats; do [ -n "$(lk "$k")" ] || miss="$miss $k"; done
  # present is not enough: a malformed value would silently skip a check, so each value must parse
  for k in rect.code rect.plot rect.axes rect.title rect.legend rect.ticks rect.watermark; do x=$(lk "$k"); [ -z "$x" ] || [[ $x =~ ^[0-9]+,[0-9]+,[0-9]+,[0-9]+$ ]] || miss="$miss $k='$x'(not x,y,w,h)"; done
  for k in axis_x axis_x_data axis_y axis_y_data; do x=$(lk "$k"); [ -z "$x" ] || [[ $x =~ ^-?$num,-?$num$ ]] || miss="$miss $k='$x'(not lo,hi)"; done
  for k in cell_w cell_h tick_px plot_pane_left_px; do x=$(lk "$k"); [ -z "$x" ] || [[ $x =~ ^[0-9]+$ ]] || miss="$miss $k='$x'(not an integer)"; done
  x=$(lk shown_s); [ -z "$x" ] || [[ $x =~ ^$num$ ]] || miss="$miss shown_s='$x'(not seconds)"
  x=$(lk fit_rgb); [ -z "$x" ] || [[ $x =~ ^[0-9a-fA-F]{6}$ ]] || miss="$miss fit_rgb='$x'(not six hex digits)"
  x=$(lk beats); [ -z "$x" ] || [[ $x =~ ^[a-z_]+(,[a-z_]+)*$ ]] || miss="$miss beats='$x'(not name,name,...)"
  for b in ${x//,/ }; do w=$(lk beat.$b); [[ $w =~ ^$num,$num$ ]] || miss="$miss beat.$b='$w'(not start,end)"; done
  [ -z "$miss" ] && res sidecar PASS "all required fields present and well-formed" || res sidecar FAIL "missing, empty or malformed:$miss (not_measured)"
fi
[ $sidecar_only = 1 ] && { [ $fails = 0 ] && echo "VERDICT PASS (sidecar only)" || echo "VERDICT FAIL ($fails)"; [ $fails = 0 ]; exit; }   # --sidecar-only: input + sidecar completeness only (the false-pass guards)
# --- pixel core
corerc=0; core=$("${VCHECK_CORE:-$HERE/vcheck-core.sh}" "$v" "$shown") || corerc=$?
[ $corerc = 0 ] || { res core FAIL "vcheck-core failed (rc $corerc)"; core=""; }
sum=$(echo "$core" | tail -1)
case $sum in SUMMARY*) frames=$(echo "$sum" | sed -n 's/.*frames=\([0-9]*\).*/\1/p'); mp=$(echo "$sum" | sed -n 's/.*min_pitch=\([0-9]*\).*/\1/p')
  for k in T3 T2pre box T2post; do n=$(echo "$sum" | sed -n "s/.*${k}_hits=\([0-9]*\).*/\1/p")
    if [ "$k" = T3 ] && [ "${mp:-0}" = 0 ]; then res T3 FAIL "no text line pitch measured in any frame (not_measured)"; continue; fi   # blank frames are skipped by the core, so all-blank must not pass
    [ "${n:-1}" = 0 ] && [ "${frames:-0}" -gt 0 ] && res "$k" PASS "0/$frames frames" || res "$k" FAIL "${n:-?}/${frames:-?} frames"; done;;
  *) [ $corerc = 0 ] && res core FAIL "no pixel-core summary (not_measured)"
     for k in T3 T2pre box T2post; do res "$k" FAIL "pixel core produced no result (not_measured)"; done;; esac
# --- layout sidecar: the plot pane edge from tmux geometry (HIT-only cross-check: never turns a pixel HIT into ok)
if [ -n "$layout" ]; then
  pl=$(lk plot_pane_left_px)
  if [ -z "$pl" ]; then res pane-edge FAIL "sidecar has no plot_pane_left_px (not_measured)"
  elif [ "$pl" -eq "$pl" ] 2>/dev/null && [ "$pl" -lt 1056 ]; then res pane-edge FAIL "plot pane left ${pl}px < 1056 (code pane < 55%)"
  elif [ "$pl" -eq "$pl" ] 2>/dev/null; then res pane-edge PASS "plot pane left ${pl}px >= 1056"
  else res pane-edge FAIL "plot_pane_left_px='$pl' is not an integer (not_measured)"; fi
elif [ $gate = 1 ]; then res pane-edge FAIL "gate take without a layout sidecar (not_measured)"
else res pane-edge N/A "no layout sidecar: pixel-only (an empty same-background pane margin is invisible to pixels)"; fi
# --- cell: the recorder's cell size is the ruled one (cell.env: 14x34), not 20x28 or 17x40
cw_=$(lk cell_w); ch_=$(lk cell_h)
if [ -n "$cw_$ch_" ]; then [ "$cw_" = "$CELL_W" ] && [ "$ch_" = "$CELL_H" ] && res cell PASS "${cw_}x${ch_}" || res cell FAIL "recorded cell ${cw_:-?}x${ch_:-?}, ruled ${CELL_W}x${CELL_H}"
elif [ $gate = 1 ]; then res cell FAIL "no cell size in the sidecar (not_measured)"; else res cell N/A "no layout sidecar"; fi
# --- font-spacing + dim-luma, measured on an unscaled LOSSLESS frame (JPEG/H.264 ringing widens ink). Gate: the recorder's <take>.frame.png
# (or --lossless) is required; plain mode falls back to a decoded video frame.
code=$(lk rect.code); read -r cx cy cw ch <<<"$(inrect "${code:-0,0,1056,1000}")"
t=$(awk -v s="$shown" -v d="$dur" 'BEGIN{t=(s<d)?s-0.3:1.0; if(t<0.5)t=0.5; printf "%.2f",t}')
[ -z "$lossless" ] && [ -f "$v.frame.png" ] && lossless="$v.frame.png"
frame_ok=1
if [ -n "$lossless" ]; then
  [ "$(identify -format '%wx%h' "$lossless" 2>/dev/null)" = 1920x1080 ] || { res font-spacing FAIL "lossless frame $lossless is not 1920x1080 (not_measured)"; res dim-luma FAIL "lossless frame $lossless is not 1920x1080 (not_measured)"; frame_ok=0; }
  [ $frame_ok = 1 ] && ffmpeg -v error -y -i "$lossless" -vf format=gray -frames:v 1 -f rawvideo "$tmp/code.raw"
elif [ $gate = 1 ]; then res font-spacing FAIL "gate take without a lossless frame ($v.frame.png or --lossless; not_measured)"; res dim-luma FAIL "gate take without a lossless frame (not_measured)"; frame_ok=0
else ffmpeg -v error -y -ss "$t" -i "$v" -frames:v 1 -vf format=gray -f rawvideo "$tmp/code.raw"; fi
if [ $frame_ok = 1 ]; then
  g=$("$tmp/glyph" 1920 1080 "$cx" "$cy" $((cx+cw)) $((cy+ch)) < "$tmp/code.raw")
  ratio=$(echo "$g" | sed -n 's/.*ratio=\([0-9.]*\).*/\1/p'); lpx=$(echo "$g" | sed -n 's/.*lp_xh=\([0-9.]*\).*/\1/p'); dim=$(echo "$g" | sed -n 's/.*dim=\([0-9]*\).*/\1/p')
  if awk -v r="${ratio:-0}" -v l="${lpx:-0}" 'BEGIN{exit !(r>=1.05 && r<=1.35 && l>=1.8)}'; then res font-spacing PASS "$g"; else res font-spacing FAIL "$g (need ratio 1.05..1.35, lp_xh >= 1.8)"; fi
  if awk -v d="${dim:-0}" 'BEGIN{exit !(d>=55)}'; then res dim-luma PASS "dimmest lines at ${dim}% of the brightest (>= 55%)"; else res dim-luma FAIL "dimmest lines at ${dim:-0}% of the brightest, need >= 55%"; fi
fi
# --- reveal-shift: the code pane must not move (0 px) when the plot appears
pr=$(lk rect.plot)
if [ -z "$pr" ] || [ "$shown" = 99999 ]; then
  if [ $gate = 1 ]; then res reveal-shift FAIL "gate take without rect.plot / shown_s (not_measured)"; else res reveal-shift N/A "no plot in this take"; fi
elif awk -v s="$shown" -v d="$dur" 'BEGIN{exit !(s>=0.2 && s+0.2<=d)}'; then
  { crop "$tmp/r0.raw" "$cx,$cy,$cw,$ch" "$(awk -v s="$shown" 'BEGIN{printf "%.2f",s-0.15}')" gray; crop "$tmp/r1.raw" "$cx,$cy,$cw,$ch" "$(awk -v s="$shown" 'BEGIN{printf "%.2f",s+0.15}')" gray; } 2>/dev/null
  rs=$(cat "$tmp/r0.raw" "$tmp/r1.raw" | "$tmp/diffwin" $((cw*ch))); mad=$(echo "$rs" | sed -n 's/.*max_mad=\([0-9.]*\).*/\1/p')
  if awk -v m="${mad:-999}" 'BEGIN{exit !(m<=2.0)}'; then res reveal-shift PASS "code pane unchanged across the reveal ($rs)"; else res reveal-shift FAIL "code pane changed at the plot reveal ($rs, need <= 2.0)"; fi
else res reveal-shift FAIL "shown_s ${shown}s is outside the take (not_measured)"; fi
# --- plot-legibility, plot-text, watermark (takes with a plot only)
if [ -z "$pr" ] || [ "$shown" = 99999 ]; then
  if [ $gate = 1 ]; then for c in plot-legibility plot-text watermark; do res $c FAIL "gate take without rect.plot / shown_s (not_measured)"; done
  else for c in plot-legibility plot-text watermark; do res $c N/A "no plot in this take"; done; fi
else
  read -r px0 py0 pw ph <<<"$(inrect "$pr")"; fit=$(lk fit_rgb); fit=${fit:-ffd700}; badfit=""
  case $fit in [0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]) ;; *) badfit=" fit_rgb='$fit' is not six hex digits"; fit=ffd700;; esac
  tf=$(awk -v d="$dur" 'BEGIN{printf "%.2f", d-0.6}')
  fr=$((16#${fit:0:2})); fg=$((16#${fit:2:2})); fb=$((16#${fit:4:2}))
  ar=$(lk rect.axes); ar=${ar:-$pr}; read -r ax0 ay0 aw ah <<<"$(inrect "$ar")"
  ffmpeg -v error -y -ss "$tf" -i "$v" -frames:v 1 -vf "crop=$aw:$ah:$ax0:$ay0,format=rgb24" -f rawvideo "$tmp/axes.raw"
  ffmpeg -v error -y -ss "$tf" -i "$v" -frames:v 1 -vf "crop=$pw:$ph:$px0:$py0,format=rgb24" -f rawvideo "$tmp/plot.raw"
  pm=$("$tmp/plot" "$aw" "$ah" $fr $fg $fb < "$tmp/axes.raw"); gm=$("$tmp/plot" "$pw" "$ph" $fr $fg $fb < "$tmp/plot.raw")
  mr=$(echo "$pm" | sed -n 's/.*modal_run=\([0-9]*\).*/\1/p'); ft=$(echo "$pm" | sed -n 's/.*fit_thick=\([0-9.]*\).*/\1/p')
  fc=$(echo "$pm" | sed -n 's/.*fit_contrast=\([0-9.]*\).*/\1/p'); fp=$(echo "$pm" | sed -n 's/.*fit_cols_pct=\([0-9]*\).*/\1/p')
  fk=$(echo "$pm" | sed -n 's/.*fit_cont_pct=\([0-9]*\).*/\1/p'); bgc=$(echo "$pm" | sed -n 's/.*bg=\([0-9a-f]*\).*/\1/p'); grid=$(echo "$gm" | sed -n 's/.*grid=\([0-9a-z]*\).*/\1/p')
  cheb(){ local a=$1 b=$2 m=0 i d; for i in 0 2 4; do d=$((16#${a:i:2}-16#${b:i:2})); [ $d -lt 0 ] && d=$((-d)); [ $d -gt $m ] && m=$d; done; echo $m; }
  bad="$badfit"
  # the fit colour must be distinguishable from the plot background and the grid/spine colour (white or yellow is fine); the line itself is then
  # MEASURED: thickness, contrast, columns covered, and continuity (scattered same-colour markers are not a line)
  [ "$(cheb "$fit" "${bgc:-000000}")" -ge 60 ] || bad="$bad fit_rgb=$fit too close to the background ${bgc}"
  [ "${grid:-none}" = none ] || [ "$(cheb "$fit" "$grid")" -ge 40 ] || bad="$bad fit_rgb=$fit too close to the grid colour $grid"
  [ "${mr:-99}" -le 6 ] || bad="$bad modal_run=$mr>6"
  awk -v a="${ft:-0}" 'BEGIN{exit !(a>=2)}' || bad="$bad fit_thick=$ft<2"
  awk -v a="${fc:-0}" 'BEGIN{exit !(a>=3)}' || bad="$bad fit_contrast=$fc<3"
  [ "${fp:-0}" -ge 30 ] || bad="$bad fit_cols=${fp}%<30%"
  [ "${fk:-0}" -ge 80 ] || bad="$bad fit_cont=${fk}%<80% (fit is not one line)"
  # axis limits: the data fills >= 80% of the axis range and lies inside it (no clipped data)
  for ax in x y; do d=$(lk axis_${ax}_data); a=$(lk axis_$ax)
    [ -n "$d" ] && [ -n "$a" ] || continue
    sp=$(awk -v d="$d" -v a="$a" 'BEGIN{split(d,D,",");split(a,A,","); printf "%.0f",(D[2]-D[1])/(A[2]-A[1])*100}')
    inside=$(awk -v d="$d" -v a="$a" 'BEGIN{split(d,D,",");split(a,A,","); print (D[1]>=A[1] && D[2]<=A[2]) ? 1 : 0}')
    [ "$sp" -ge 80 ] || bad="$bad axis_${ax}_span=${sp}%<80%"
    [ "$inside" = 1 ] || bad="$bad axis_${ax}_data=$d outside axis_$ax=$a (clipped)"
  done
  # rectangles must not overlap: watermark vs code, title, legend, axes (it sits in the plot pane band above the chart); plot vs code
  ov(){ local a b; a=$(lk rect.$1); b=$(lk rect.$2); [ -n "$a" ] && [ -n "$b" ] || return 0
    echo "$a $b" | awk '{split($1,A,",");split($2,B,","); if(A[1]<B[1]+B[3]&&B[1]<A[1]+A[3]&&A[2]<B[2]+B[4]&&B[2]<A[2]+A[4]) exit 1}' || bad="$bad overlap($1,$2)"; }
  for p in watermark:code watermark:title watermark:legend watermark:axes plot:code; do ov "${p%:*}" "${p#*:}"; done
  pmg=${pm% grid=*}; [ -z "$bad" ] && res plot-legibility PASS "$pmg grid=${grid}" || res plot-legibility FAIL "$pmg grid=${grid};$bad"
  # plot-text: title/legend >= 26-28 px and ticks >= 22-24 px, MEASURED as glyph height / 0.72 on the frame (1 px coverage tolerance: >= 25 / >= 21);
  # title ink starts at y >= 72 (clear of the watermark band); the legend holds the fit swatch (fit colour) and its label; declared tick_px is honest
  bad=""; tdet=""
  tm(){ local r; r=$(lk rect."$1"); [ -n "$r" ] || { bad="$bad rect.$1 missing"; return; }
    local x y w h; read -r x y w h <<<"$(inrect "$r")"
    ffmpeg -v error -y -ss "$tf" -i "$v" -frames:v 1 -vf "crop=$w:$h:$x:$y,format=rgb24" -f rawvideo "$tmp/t.raw"
    TM=$("$tmp/text" "$w" "$h" $fr $fg $fb < "$tmp/t.raw"); TY=$y; TX=$x
    tdet="$tdet $1:[$TM]"; }
  size(){ echo "$TM" | sed -n 's/.*size=\([0-9.]*\).*/\1/p'; }
  tm title; ts=$(size); ty0=$(echo "$TM" | sed -n 's/.*bbox=[0-9]*,\([0-9]*\),.*/\1/p'); tink=$(echo "$TM" | sed -n 's/.*ink_px=\([0-9]*\).*/\1/p')
  awk -v s="${ts:-0}" 'BEGIN{exit !(s>=25)}' || bad="$bad title size ${ts:-0}px<26"
  [ "${tink:-0}" -gt 0 ] && [ $((TY + ${ty0:-0})) -ge 72 ] || bad="$bad title ink top y=$((TY + ${ty0:-0}))<72 (or no title)"
  tm legend; ls_=$(size); lfit=$(echo "$TM" | sed -n 's/.*fit_px=\([0-9]*\).*/\1/p')
  awk -v s="${ls_:-0}" 'BEGIN{exit !(s>=25)}' || bad="$bad legend size ${ls_:-0}px<26"
  [ "${lfit:-0}" -ge 20 ] || bad="$bad legend has no fit swatch/label in the fit colour (fit_px=${lfit:-0}<20)"
  tm ticks; ks=$(size)
  awk -v s="${ks:-0}" 'BEGIN{exit !(s>=21)}' || bad="$bad tick size ${ks:-0}px<22"
  dtk=$(lk tick_px); { [ -n "$dtk" ] && awk -v d="$dtk" -v m="${ks:-0}" 'BEGIN{x=d-m; if(x<0)x=-x; exit !(d>=22 && x<=4)}'; } || bad="$bad declared tick_px=${dtk:-none} (need >= 22) disagrees with measured ${ks:-0}"
  [ -z "$bad" ] && res plot-text PASS "title ${ts}px legend ${ls_}px ticks ${ks}px" || res plot-text FAIL "$bad;$tdet"
  # watermark: default placement is the top-right corner of the frame, in the band above the plot title (y+h <= 72) and right of the plot pane's
  # left edge, so it cannot overlap rect.code (which ends before that edge: lib.sh layout_rects and gen.sh use the same rect), the title or the plot body
  wm=$(lk rect.watermark); bad=""; ppl=$(lk plot_pane_left_px)
  if [ -z "$wm" ]; then bad=" rect.watermark missing"; else read -r wx wy ww wh <<<"$(inrect "$wm")"
    awk -v x="$wx" -v y="$wy" -v w="$ww" -v h="$wh" -v p="${ppl:-1056}" 'BEGIN{exit !(y+h<=72 && x>=p && x+w<=1920)}' || bad=" watermark $wm is not top-right (needs y+h <= 72, x >= plot pane left ${ppl:-1056}, x+w <= 1920)"; fi
  [ -z "$bad" ] && res watermark PASS "$wm" || res watermark FAIL "$bad"
fi
# --- hold-fade: the final hold is not faded (last frame's mean luma >= 90% of the frame just after the reveal)
if [ "$shown" != 99999 ] && awk -v s="$shown" -v d="$dur" 'BEGIN{exit !(s+0.4<d-0.1)}'; then
  lum(){ ffmpeg -v error -y -ss "$1" -i "$v" -frames:v 1 -vf scale=1:1:flags=area,format=gray -f rawvideo - | od -An -tu1 | tr -d ' '; }
  l0=$(lum "$(awk -v s="$shown" 'BEGIN{printf "%.2f",s+0.4}')"); l1=$(lum "$(awk -v d="$dur" 'BEGIN{printf "%.2f",d-0.1}')")
  if awk -v a="${l0:-0}" -v b="${l1:-0}" 'BEGIN{exit !(a>0 && b>=0.9*a)}'; then res hold-fade PASS "luma ${l0} -> ${l1}"; else res hold-fade FAIL "final frame luma ${l1:-?} < 90% of ${l0:-?}: the hold is faded"; fi
elif [ $gate = 1 ]; then res hold-fade FAIL "no room between the reveal and the end (not_measured)"; else res hold-fade N/A "no plot reveal"; fi
# --- beats: MEASURED from the beat snapshots (<layout>.beats/<beat>.txt, the recorder's capture of what the screen held) and the frames.
# Required in gate mode, all five: cargo_toml ([dependencies] holds aprender itself, any other dep beyond polars/aprender/aprender-viz explained
# by a trailing comment), tree (cargo tree -p aprender), version (rustc/cargo --version), call (a visible aprender call), stdout (a number with a unit).
# Each beat window must be >= 4 s, inside the take, and the code pane must stay put in it (it cannot be a window the take does not hold).
bl=$(lk beats)
if [ -z "$bl" ]; then [ $gate = 1 ] && res beats FAIL "no beats key in the sidecar (not_measured)" || res beats N/A "no beats declared (plain mode)"
else
  bd="${layout}.beats"; bad=""
  for need in cargo_toml tree version call stdout; do case ",$bl," in *",$need,"*) ;; *) bad="$bad $need:not listed in beats=$bl";; esac; done
  for b in ${bl//,/ }; do f="$bd/$b.txt"; s=$(lk beat.$b)
    [ -s "$f" ] || { bad="$bad $b:snapshot missing or empty"; continue; }
    case $b in
      cargo_toml) deps=$(awk '/^\[/{ sec=$0; sub(/[ \t]*(#.*)?$/,"",sec)
            if (sec ~ /^\[dependencies\.[^]]+\]$/) { n=sec; sub(/^\[dependencies\./,"",n); sub(/\]$/,"",n); gsub(/"/,"",n); print n "\t" ($0 ~ /#[ \t]*[^ \t#]/ ? "E" : "-") }; next }
          sec=="[dependencies]" && /^[ \t]*[A-Za-z0-9_-]+[ \t]*(=|\.)/ { n=$0; sub(/^[ \t]*/,"",n); sub(/[ \t]*(=|\.).*/,"",n); print n "\t" ($0 ~ /#[ \t]*[^ \t#]/ ? "E" : "-") }' "$f")
        echo "$deps" | cut -f1 | grep -qx 'aprender' || bad="$bad cargo_toml:[dependencies] has no 'aprender' (aprender-viz or dev-dependencies do not count)"
        extra=$(echo "$deps" | awk -F'\t' 'NF && $1!="polars" && $1!="aprender" && $1!="aprender-viz" && $2!="E"{print $1}' | head -1)
        [ -z "$extra" ] || bad="$bad cargo_toml:unexplained dependency '$extra' (add a trailing # reason)";;
      tree) grep -Eq '^[^A-Za-z0-9]*aprender v[0-9]' "$f" || bad="$bad tree:no 'aprender vX' line (cargo tree -p aprender)";;
      version) grep -Eq '(rustc|cargo) [0-9]+\.[0-9]+' "$f" || bad="$bad version:no rustc/cargo --version";;
      call) grep -v '^[[:space:]]*use ' "$f" | grep -Eq 'aprender::[A-Za-z0-9_:]+[[:space:]]*(\(|!|::<)' || bad="$bad call:no visible aprender call";;
      stdout) grep -Ev '^[[:space:]]*(Compiling|Finished|Running|Blocking|Downloaded)' "$f" | grep -Eq '[0-9][0-9.,]*[ ]?(g|mm|cm|kg|ms|s|%)([^A-Za-z]|$)' || bad="$bad stdout:no number with a unit";;
      *) bad="$bad $b:unknown beat";;
    esac
    ws=${s%%,*}; we=${s##*,}
    if ! awk -v a="$ws" -v b="$we" -v d="$dur" 'BEGIN{exit !(a ~ /^[0-9]+(\.[0-9]+)?$/ && b ~ /^[0-9]+(\.[0-9]+)?$/ && b-a>=4 && b-a<=8 && b<=d+0.1)}'; then bad="$bad $b:window '${s:-none}' is not 4..8 s inside the ${dur}s take"; continue; fi
    awk -v a="$ws" -v p="${prev_end:-0}" 'BEGIN{exit !(a+0.05>=p)}' || bad="$bad $b:window starts at ${ws}s before the previous beat ended (${prev_end}s)"
    prev_end=$we
    wl=$(awk -v a="$ws" -v b="$we" 'BEGIN{printf "%.2f",b-a-0.5}')
    ffmpeg -v error -y -ss "$(awk -v a="$ws" 'BEGIN{printf "%.2f",a+0.25}')" -t "$wl" -i "$v" -vf "fps=2,crop=$cw:$ch:$cx:$cy,format=gray" -f rawvideo "$tmp/win.raw"
    wr=$("$tmp/diffwin" $((cw*ch)) < "$tmp/win.raw"); wm_=$(echo "$wr" | sed -n 's/.*max_mad=\([0-9.]*\).*/\1/p'); wn=$(echo "$wr" | sed -n 's/.*frames=\([0-9]*\).*/\1/p')
    awk -v m="${wm_:-999}" -v n="${wn:-0}" 'BEGIN{exit !(n>=6 && m<=3.0)}' || bad="$bad $b:the screen does not hold through its window ($wr)"
  done
  [ -z "$bad" ] && res beats PASS "$bl" || res beats FAIL "$bad"
fi
# --- frozen frames: no still stretch > 3.5 s outside the declared beat windows (a beat is held >= 4 s by design: the recorder hides the cursor, so a
# real beat is bit-identical); the final hold (run reaching the end) 2.5..3.5 s. Freeze events are cut by the beat windows of the sidecar.
wins=""; for b in $(lk beats | tr ',' ' '); do w=$(lk beat.$b); [[ $w =~ ^[0-9.]+,[0-9.]+$ ]] && wins="$wins $w"; done
ffmpeg -hide_banner -i "$v" -vf freezedetect=n=0.0001:d=0.5 -an -f null - 2>&1 | sed -n 's/.*freeze_\(start\|duration\): \([0-9.]*\).*/\1 \2/p' > "$tmp/fz.txt"
fz=$(awk -v d="$dur" -v wins="$wins" '
  function seg(s,e,   i,j,m,nl,nh,a,b,k){ n=1; lo[1]=s; hi[1]=e
    for(k=1;k<=nw;k++){ a=WA[k]; b=WB[k]; m=0
      for(i=1;i<=n;i++){ if(b<=lo[i]||a>=hi[i]){ m++; nl[m]=lo[i]; nh[m]=hi[i]; continue }
        if(a>lo[i]){ m++; nl[m]=lo[i]; nh[m]=a }; if(b<hi[i]){ m++; nl[m]=b; nh[m]=hi[i] } }
      n=m; for(j=1;j<=m;j++){ lo[j]=nl[j]; hi[j]=nh[j] } }
    if(e>=d-0.15){ fin=e-s; return }   # the run reaching the end is the final hold, measured whole (it may begin inside the last beat window)
    for(i=1;i<=n;i++){ len=hi[i]-lo[i]; if(len>mid) mid=len } }
  BEGIN{ nw=split(wins,W," "); for(k=1;k<=nw;k++){ split(W[k],P,","); WA[k]=P[1]+0; WB[k]=P[2]+0 } }
  /^start/{s=$2} /^duration/{ if(s!=""){ seg(s,s+$2); s="" } }
  END{ if(s!="") seg(s,d); printf "%.2f %.2f", mid+0, fin+0 }' "$tmp/fz.txt")
read -r mid fin <<<"$fz"
bad=""; awk -v m="$mid" 'BEGIN{exit !(m<=3.5)}' || bad="$bad still stretch ${mid}s>3.5s outside the declared beat windows"
awk -v f="$fin" 'BEGIN{exit !(f>=2.5 && f<=3.5)}' || bad="$bad final hold ${fin}s outside 2.5..3.5s"
[ -z "$bad" ] && res frozen PASS "outside-beat still=${mid}s final=${fin}s" || res frozen FAIL "outside-beat still=${mid}s final=${fin}s;$bad"
[ $fails = 0 ] && { echo "VERDICT PASS"; exit 0; } || { echo "VERDICT FAIL ($fails)"; exit 1; }
