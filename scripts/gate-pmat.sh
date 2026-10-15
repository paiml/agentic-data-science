#!/usr/bin/env bash
# pmat quality-gate on the languages pmat can analyze (pilot R5: Rust, Kotlin, Lean).
# Julia and R have no pmat analyzer and are gated by their native tools (gate-r, gate-julia).
set -uo pipefail
cd "$(dirname "$0")/.."
ran=0
for d in rust kotlin lean; do
  [ -d "$d" ] || continue
  ran=1
  pmat quality-gate -p "$d" -q || { echo "pmat FAIL $d"; exit 1; }
done
[ "$ran" = 1 ] && echo "pmat OK" || echo "pmat: no Rust/Kotlin/Lean package yet"
