#!/usr/bin/env bash
# Rust gate: fmt, clippy -D warnings, llvm-cov lines=100 functions=100 regions>=95, no crates.io trueno.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root/rust/ads-rust"
cargo fmt --check
cargo clippy --all-targets --locked -- -D warnings
if cargo tree -i trueno --locked 2>/dev/null | grep -q 'registry+'; then echo "FAIL: crates.io trueno"; exit 1; fi
cargo llvm-cov --all-targets --locked --fail-under-lines 100 --fail-under-functions 100 --fail-under-regions 95
# The tracked figure pmat reads must equal the measured line coverage, so it can never go stale.
meas=$(cargo llvm-cov report --json --summary-only | jq '.data[0].totals.lines.percent')
jq -e --argjson m "$meas" ".coverage == \$m" "$root/.pmat-metrics/coverage.json" >/dev/null || { echo "FAIL: .pmat-metrics/coverage.json != measured $meas"; exit 1; }
for e in a-m1-p1 a-m1-p1-profile; do ADS_ROOT="$root" cargo run -q --locked --example "$e" | tail -n 1 | grep -q '^contract: .* OK$' || { echo "FAIL example $e"; exit 1; }; done
echo "rust gate OK"
