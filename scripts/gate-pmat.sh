#!/usr/bin/env bash
# pmat quality-gate on the languages pmat can analyze (pilot R5: Rust only; Kotlin runs its measured pmat checks in gate-kotlin, Lean has no analyzer, see gate-lean).
# Julia and R have no pmat analyzer and are gated by their native tools (gate-r, gate-julia).
# Rust: the crate dir is passed (dead-code needs Cargo.toml) and the coverage check is left to
# cargo llvm-cov (gate-rust.sh, lines=100): pmat's coverage check only reads a report it did not make.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
ran=0
if [ -d rust ]; then
  ran=1
  pmat quality-gate -p rust/ads-rust --checks dead-code,complexity,satd,entropy,security,duplicates,provability -q || { echo "pmat FAIL rust"; exit 1; }
fi
[ "$ran" = 1 ] && echo "pmat OK" || echo "pmat: no Rust/Lean package yet"
