#!/usr/bin/env bash
# Rust gate: fmt, clippy -D warnings, llvm-cov lines=100 functions=100 regions>=95, no crates.io trueno.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root/rust/ads-rust"
cargo fmt --check
cargo clippy --all-targets --locked -- -D warnings
if cargo tree -i trueno --locked 2>/dev/null | grep -q 'registry+'; then echo "FAIL: crates.io trueno"; exit 1; fi
cargo llvm-cov --all-targets --locked --fail-under-lines 100 --fail-under-functions 100 --fail-under-regions 95
# No tracked figure (T12p refuses any .pmat-metrics): the measured line coverage itself must be exactly 100.
meas=$(cargo llvm-cov report --json --summary-only | jq '.data[0].totals.lines.percent')
jq -en --argjson m "$meas" '$m == 100' >/dev/null || { echo "FAIL: measured line coverage $meas != 100"; exit 1; }
for e in a-m1-p1 a-m1-p1-profile a-m2-p2-ols a-m2-p2-cv a-m3-p3-tree a-m3-p3-kmeans a-m4-p4-pipeline a-m4-p4-bench; do ADS_ROOT="$root" cargo run -q --locked --example "$e" | tail -n 1 | grep -q '^contract: .* OK$' || { echo "FAIL example $e"; exit 1; }; done
echo "rust gate OK"
