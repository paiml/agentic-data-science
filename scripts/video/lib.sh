#!/bin/bash
# lib.sh: sourced by the per-course recorders (rec.sh). Gives them the shared cell size and writes the layout sidecar vcheck reads.
# usage:  . "$(dirname "$0")/../../scripts/video/lib.sh"   (any path to this file)
VIDEO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$VIDEO_DIR/cell.env"
# termctrl start/video flags for the shared cell size
cell_args(){ echo "--cols $COLS --rows $ROWS --cell-width $CELL_W --cell-height $CELL_H"; }
video_args(){ echo "--cell-width $CELL_W --cell-height $CELL_H --padding 0 --pixel-ratio 1 --fps 20 --hide-cursor --tail-ms 0"; }
# layout_rects <plot_pane_left_px>: the rect lines every recorder AND the proofs (tests/gen.sh) use, so vcheck sees one geometry.
# rect.code = the code pane text box (one cell in from the left, two cells short of the plot pane); rect.watermark = the PREVIEW mark in the
# top-right corner of the frame, in the band above the plot title (y+h <= 72), over the plot pane, so it can never overlap rect.code.
WM_W=200; WM_H=40
layout_rects(){ local pl=$1
  echo "rect.code=$CELL_W,$((CELL_H/2)),$((pl-1-2*CELL_W)),$((ROWS*CELL_H-CELL_H))"; echo "rect.watermark=$((1920-WM_W-CELL_W)),16,$WM_W,$WM_H"; }
# layout_from_tmux <tmux args...> <plot_pane_id>: the sidecar lines for the CURRENT tmux geometry (call after the plot-shown resize).
# Prints cell_w/cell_h, plot_pane_left_px (pane_left x CELL_W + 1 px grid pad) and layout_rects.
layout_from_tmux(){ local pane=${!#}; local -a t=("${@:1:$#-1}")
  local left _w; read -r left _w < <(tmux "${t[@]}" list-panes -F '#{pane_id} #{pane_left} #{pane_width}' | awk -v p="$pane" '$1==p{print $2, $3}')
  [ -n "$left" ] || { echo "layout_from_tmux: pane $pane not found" >&2; return 1; }
  echo "cell_w=$CELL_W"; echo "cell_h=$CELL_H"; echo "plot_pane_left_px=$((left*CELL_W+1))"; layout_rects $((left*CELL_W+1)); }
# layout_write <file> <line>...: write the sidecar (key=value lines; vcheck takes the last occurrence of a key)
layout_write(){ local f=$1; shift; printf '%s\n' "$@" > "$f"; }
