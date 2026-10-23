#!/usr/bin/env bash
# B-M2 video 10-wrapup: wrap-up, both P2 contracts
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
for e in b-m2-p2-ols b-m2-p2-cv; do julia --project="$PKG" "julia/AgenticDS.jl/examples/$e/run.jl" 2>/dev/null | grep '^contract:'; done
echo "contract: b-m2 wrap-up OK"
