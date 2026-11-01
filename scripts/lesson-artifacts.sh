#!/usr/bin/env bash
# Build a lesson's CI artifacts: stdout.txt, plot.svg, manifest.sha256 (ADS-DEMO-001 R-2, R-5).
# usage: lesson-artifacts.sh <lesson> <lang> <outdir>   (rust only so far)
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"; lesson="$1"; lang="$2"; out="$3"
case "$lang" in rust) ;; r) exec "$root/lessons/anscombe/r/lesson.sh" "$3" ;; *) echo "FAIL: no runner for $lang yet"; exit 1 ;; esac
mkdir -p "$out"; out="$(cd "$out" && pwd)"
(cd "$root/rust/ads-rust" && ADS_ROOT="$root" ADS_OUT="$out" cargo run -q --locked --example "$lesson" >/dev/null)
(cd "$out" && sha256sum stdout.txt plot.svg > manifest.sha256)
echo "artifacts OK: $out"
