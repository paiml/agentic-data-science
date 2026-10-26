#!/bin/bash
# lab.sh <takes-dir>: nightly LAB run of vcheck --gate over real takes (*.mp4 with a sibling *.mp4.layout). never in a PR check.
# No directory (VIDEO_TAKES unset or empty), no takes, or a take without its sidecar, is not_measured = FAIL. Compose's *.base.mp4 intermediates are not takes.
# A vcheck that dies without a CHECK line (helper build failed, bad args) is printed, never swallowed. LAB_VCHECK overrides the checker (proofs only).
set -u
HERE=$(cd "$(dirname "$0")" && pwd); D=${1:-}; VC=${LAB_VCHECK:-$HERE/vcheck.sh}
[ -n "$D" ] && [ -d "$D" ] || { echo "FAIL: no takes directory (VIDEO_TAKES unset, empty or not a directory: not_measured)"; exit 1; }
out=$(mktemp "${TMPDIR:-/tmp}/lab.XXXXXX"); trap 'rm -f "$out"' EXIT
shopt -s nullglob globstar; n=0; bad=0
for v in "$D"/**/*.mp4; do case $v in *.base.mp4) continue;; esac; n=$((n+1)); l="$v.layout"
  if [ ! -f "$l" ]; then echo "FAIL $v: no layout sidecar (not_measured)"; bad=$((bad+1)); continue; fi
  "$VC" "$v" "$l" --gate > "$out" 2>&1; rc=$?
  if [ $rc = 0 ]; then echo "ok   $v"; else echo "FAIL $v (rc $rc)"
    if grep -q '^CHECK .* FAIL' "$out"; then grep '^CHECK .* FAIL' "$out" | cut -c1-200; else tail -n 5 "$out" | cut -c1-200; fi; bad=$((bad+1)); fi
done
[ $n -gt 0 ] || { echo "FAIL: no takes under $D (not_measured)"; exit 1; }
echo "takes: $n, failed: $bad"; [ $bad = 0 ]
