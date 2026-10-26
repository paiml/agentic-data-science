#!/usr/bin/env bash
# pmat quality-gate on the languages pmat can analyze: Rust and Kotlin.
# pmat has no analyzer for R, Julia or Lean, so it checks none of
# their code. `pmat analyze hardcoded-paths` on courses/C-r read the
# yaml/json files only (0 of the .R files), so it is not run here.
# R is gated by scripts/gate-r.sh (covr, lintr, styler, testthat).
# Julia and Lean are gated by gate-julia and gate-lean.
# This script is run by `make gate` and is not a CI job (ci.yml).
set -uo pipefail
cd "$(dirname "$0")/.."
ran=0
for d in rust kotlin; do
  [ -d "$d" ] || continue
  ran=1
  pmat quality-gate -p "$d" -q || { echo "pmat FAIL $d"; exit 1; }
done
[ "$ran" = 1 ] && echo "pmat OK" || echo "pmat: no Rust/Kotlin package yet"
