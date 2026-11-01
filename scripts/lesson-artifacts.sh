#!/usr/bin/env bash
# Build a lesson's CI artifacts: stdout.txt, plot.svg, manifest.sha256 (ADS-DEMO-001 R-2, R-5).
# usage: lesson-artifacts.sh <lesson> <lang> <outdir>   (rust, lean so far; lesson anscombe)
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"; lesson="$1"; lang="$2"; out="$3"
mkdir -p "$out"; out="$(cd "$out" && pwd)"
case "$lang" in
  rust) (cd "$root/rust/ads-rust" && ADS_ROOT="$root" ADS_OUT="$out" cargo run -q --locked --example "$lesson" >/dev/null) ;;
  lean) [ "$lesson" = anscombe ] || { echo "FAIL: no lean lesson $lesson"; exit 1; }
        export PATH="$HOME/.elan/bin:$PATH"
        (cd "$root/lean/anscombe" && lake build >/dev/null && ADS_ROOT="$root" ADS_OUT="$out" lake exe anscombe >/dev/null) ;;
  *) echo "FAIL: no runner for $lang yet"; exit 1 ;;
esac
(cd "$out" && sha256sum stdout.txt plot.svg > manifest.sha256)
echo "artifacts OK: $out"
