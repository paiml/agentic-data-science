#!/usr/bin/env bash
# frame-check.sh VIDEO SCREEN.txt ROWS REGEX...   every-frame check of the DELIVERED mp4 (all frames at 20 fps)
# F1 no blank frame (luma stddev); F2 every frame in the code pane (top 60%) has >=2 saturated hue buckets until the run command starts;
# F3 line pitch MEASURED from the mp4 gutter (autocorrelation lag of the line-number column) >= 28 px;
# F4 final screen text (termctrl dump) matches every REGEX and holds no /mnt or /home path;
# F5 LAST frame is not blank and carries the output text (non-black pixels in the bottom pane);
# F6 the last 3 s are one held screen (frame-to-frame RMSE ~0): no detach/blank tail.
# exit 0 pass, 1 fail
set -u
V=${1:?video}; T=${2:?screen}; ROWS=${3:?rows}; shift 3
W=$(mktemp -d ${PV_ROOT:?set PV_ROOT}/fc.XXXXXX); fail=0
ffmpeg -v error -y -i "$V" -vf "fps=20,crop=1695:1080:0:0,scale=565:-2" "$W/f%05d.png" || { echo FAIL decode; exit 1; }
n=0; blank=0; nohue=0
for f in "$W"/f*.png; do
  n=$((n+1))
  sd=$(convert "$f" -colorspace Gray -format '%[fx:standard_deviation*1000]' info:)
  [ "${sd%.*}" -lt 20 ] && { blank=$((blank+1)); echo "F1 blank frame $n"; }
done
# hue test on the first 60% of frames' code pane (code pane stays on screen to the end; test all)
for f in "$W"/f*.png; do
  h=$(convert "$f" -crop 565x216+0+0 +repage txt:- | awk 'match($0,/\(([0-9]+),([0-9]+),([0-9]+)/,m){r=m[1];g=m[2];b=m[3];mx=(r>g?r:g);mx=(mx>b?mx:b);mn=(r<g?r:(g<b?g:b));mn=(b<mn?b:mn); if(mx-mn>60){k=int(r/64)*16+int(g/64)*4+int(b/64);s[k]=1}} END{c=0;for(k in s)c++;print c}')
  [ "${h:-0}" -lt 2 ] && { nohue=$((nohue+1)); echo "F2 <2 hues $(basename $f)"; }
done
echo "frames=$n blank=$blank low_hue=$nohue"
[ $blank -gt 0 ] && fail=1; [ $nohue -gt 0 ] && fail=1
# F3 measured pitch from the gutter of the last frame at delivered size
ffmpeg -v error -y -sseof -0.5 -i "$V" -frames:v 1 "$W/last.png"
pitch=$(convert "$W/last.png" -crop 100x580+115+10 +repage -colorspace Gray -resize 1x580! txt:- | awk -f "$(dirname "$0")/pitch.awk")
[ "${pitch:-0}" -ge 28 ] && echo "ok F3 measured line pitch ${pitch} px" || { echo "F3 measured line pitch ${pitch:-0} px < 28"; fail=1; }
for r in "$@"; do grep -q -E "$r" "$T" && echo "ok F4 '$r'" || { echo "F4 missing '$r'"; fail=1; }; done
grep -q -E '/mnt/|/home/' "$T" && { echo "F4 host path on screen"; fail=1; } || echo "ok F4 no host path"
# F5 last frame content: bottom pane (y>=700) must hold non-black pixels
nb=$(convert "$W/last.png" -crop 1695x380+0+700 +repage -colorspace Gray -threshold 25% -format '%[fx:mean*100000]' info:)
sdl=$(convert "$W/last.png" -colorspace Gray -format '%[fx:standard_deviation*1000]' info:)
{ [ "${nb%.*}" -ge 100 ] && [ "${sdl%.*}" -ge 20 ]; } && echo "ok F5 last frame carries output (ink=$nb sd=$sdl)" || { echo "F5 last frame blank-ish (ink=$nb sd=$sdl)"; fail=1; }
# F6 last 3 s held
mx=0; prev=""
for f in $(ls "$W"/f*.png | tail -n 60); do
  [ -n "$prev" ] && { d=$(compare -metric RMSE "$prev" "$f" null: 2>&1 | awk '{print int($1)}'); [ "${d:-0}" -gt "$mx" ] && mx=$d; }
  prev=$f
done
[ "$mx" -le 200 ] && echo "ok F6 final 3 s held (max step rmse $mx)" || { echo "F6 tail not held (max step rmse $mx)"; fail=1; }
mv "$W" "$W.done" 2>/dev/null; [ $fail = 0 ] && echo PASS || echo FAIL; exit $fail
