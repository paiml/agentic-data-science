#!/bin/bash
# compose.sh <rec.termctrl> <plot.png> <out.mp4> [layout-from-recorder] [plot.meta]
# Composite: terminal at CELL_WxCELL_H, 1:1 (padded, never scaled) + the native 720x1080 plot at PLOT_X from the "plot-shown" mark.
# Writes <out>.layout next to the video: the recorder's layout lines (pane geometry) + shown_s + rect.plot + the chart's own metadata
# (plot.meta: fit_rgb, axis_*, tick_px, rect.axes/title/legend/ticks/watermark, beats=<name>,<name>,... and one beat.<name>=<start_s>,<end_s> line per beat, 4..8 s each), which vcheck.sh reads; plus
# cell_w/cell_h from cell.env. Also writes <out>.frame.png (a LOSSLESS composite frame 1 s after the reveal: vcheck's font-spacing gate reads it,
# never the h264 take) and copies the beat snapshots <plot.meta>.beats/ to <out>.layout.beats/ when the recorder wrote them. Needs termctrl, ffmpeg, ImageMagick.
set -eu
. "$(dirname "$0")/lib.sh"
REC=${1:?rec.termctrl}; PLOT=${2:?plot.png}; OUT=${3:?out.mp4}; REC_LAYOUT=${4:-}; META=${5:-${PLOT%.png}.meta}
BASE=${OUT%.mp4}.base.mp4; EDIT=${OUT%.mp4}.edit.json
mark(){ termctrl markers "$REC" | awk -v n="$1" '$2==n{print $1}'; }
OPEN=$(mark open); SHOWN=$(mark plot-shown); SAVED=$(mark plot-saved)
[ -n "$OPEN" ] && [ -n "$SHOWN" ] && [ -n "$SAVED" ] && [ -s "$PLOT" ] || { echo "FAIL: mark or plot missing"; exit 1; }
awk -v s="$SAVED" -v h="$SHOWN" 'BEGIN{ if (h<s) { print "FAIL plot shown before saved"; exit 1 } }'
[ "$(identify -format '%wx%h' "$PLOT")" = "${PLOT_W}x${PLOT_H}" ] || { echo "FAIL plot not ${PLOT_W}x${PLOT_H}"; exit 1; }
echo '{"clips":[{"from":"open","to":"end"}]}' > "$EDIT"
# shellcheck disable=SC2046
termctrl video "$REC" --edit "$EDIT" $(video_args) -o "$BASE"
T=$(awk -v a="$SHOWN" -v o="$OPEN" 'BEGIN{printf "%.2f",(a-o)/1000}')
PADX=$(( (1920 - COLS*CELL_W) / 2 )); PADY=$(( (1080 - ROWS*CELL_H) / 2 ))
ffmpeg -y -v error -i "$BASE" -i "$PLOT" -filter_complex "[0:v]pad=1920:1080:$PADX:$PADY:color=0x1e1e1e[b];[b][1:v]overlay=$PLOT_X:0:enable='gte(t,$T)'[o]" \
  -map "[o]" -pix_fmt yuv420p -c:v libx264 -crf 14 -r 20 "$OUT"
{ [ -n "$REC_LAYOUT" ] && [ -f "$REC_LAYOUT" ] && cat "$REC_LAYOUT"; echo "shown_s=$T"; echo "rect.plot=$PLOT_X,0,$PLOT_W,$PLOT_H"
  [ -f "$META" ] && cat "$META"; } > "$OUT.layout"
echo "cell_w=$CELL_W" >> "$OUT.layout"; echo "cell_h=$CELL_H" >> "$OUT.layout"
ffmpeg -y -v error -ss "$(awk -v t="$T" 'BEGIN{printf "%.2f",t+1}')" -i "$BASE" -i "$PLOT" -filter_complex "[0:v]pad=1920:1080:$PADX:$PADY:color=0x1e1e1e[b];[b][1:v]overlay=$PLOT_X:0[o]" \
  -map "[o]" -frames:v 1 "$OUT.frame.png"
[ -d "$META.beats" ] && { rm -rf "$OUT.layout.beats"; cp -r "$META.beats" "$OUT.layout.beats"; }
echo "composed $OUT (plot shown at $T s); layout $OUT.layout"
