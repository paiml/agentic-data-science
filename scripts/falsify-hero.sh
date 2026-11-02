#!/usr/bin/env bash
# F5: removing the hero, making it stale, or dropping it from the README must turn the hero check RED; the clean tree GREEN.
# usage: falsify-hero.sh <artifacts-dir> (or ANSCOMBE_ARTS). Stages EVERY language in parity/anscombe.landed: rust is built here;
# every other landed language needs <artifacts-dir>/<lang>/plot.svg (CI downloads it). A missing one is RED, never skipped.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"; t="$(mktemp -d)"; trap 'rm -rf "${t:?}"' EXIT
arts="${1:-${ANSCOMBE_ARTS:-}}"
while read -r lang; do [ -n "$lang" ] || continue; mkdir -p "$t/$lang"
  if [ "$lang" = rust ]; then bash "$root/scripts/lesson-artifacts.sh" anscombe rust "$t/rust" >/dev/null
  else [ -s "$arts/$lang/plot.svg" ] || { echo "FAIL: landed language $lang has no plot.svg under \"$arts\" (pass the artifacts dir)"; exit 1; }
    cp "$arts/$lang/plot.svg" "$t/$lang/plot.svg"; fi
done < "$root/parity/anscombe.landed"
bash "$root/scripts/hero.sh" check "$t" >/dev/null || { echo "FAIL: clean hero not green"; exit 1; }
for f in assets/hero.svg assets/hero.sha256 README.md; do cp "$root/$f" "$t/save"
  case "$f" in
    assets/hero.svg) echo '<!-- x -->' >> "$root/$f"; why="stale svg";;
    assets/hero.sha256) echo 0 > "$root/$f"; why="stale sha256";;
    README.md) sed -i 's#(assets/hero.svg)#(x.svg)#' "$root/$f"; why="README without hero";;
  esac
  rc=0; bash "$root/scripts/hero.sh" check "$t" >/dev/null 2>&1 || rc=$?; cp "$t/save" "$root/$f"
  [ "$rc" -ne 0 ] || { echo "FAIL: F5 $why stayed green"; exit 1; }
done
mv "$root/assets/hero.svg" "$t/hero.bak"; rc=0; bash "$root/scripts/hero.sh" check "$t" >/dev/null 2>&1 || rc=$?; mv "$t/hero.bak" "$root/assets/hero.svg"
[ "$rc" -ne 0 ] || { echo "FAIL: F5 missing hero stayed green"; exit 1; }
echo "F5 OK: clean GREEN; missing, stale svg, stale sha256, unreferenced all RED"
