#!/usr/bin/env bash
# pmat quality-gate on the languages pmat can analyze (pilot R5: Rust, Kotlin; Lean has no analyzer, see gate-lean).
# Julia and R have no pmat analyzer and are gated by their native tools (gate-r, gate-julia).
# Rust: the crate dir is passed (dead-code needs Cargo.toml) and the coverage check is left to
# cargo llvm-cov (gate-rust.sh, lines=100): pmat's coverage check only reads a report it did not make.
set -uo pipefail
cd "$(dirname "$0")/.."
ran=0
if [ -d rust ]; then
  ran=1
  pmat quality-gate -p rust/ads-rust --checks dead-code,complexity,satd,entropy,security,duplicates,provability -q || { echo "pmat FAIL rust"; exit 1; }
fi
for d in kotlin; do
  [ -d "$d" ] || continue
  ran=1
  pmat quality-gate -p "$d" -q || { echo "pmat FAIL $d"; exit 1; }
done
[ "$ran" = 1 ] && echo "pmat OK" || echo "pmat: no Rust/Kotlin/Lean package yet"
