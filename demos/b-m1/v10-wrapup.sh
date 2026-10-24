#!/usr/bin/env bash
# B-M1 video 10-wrapup: wrap-up, both P1 contracts
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
for e in b-m1-p1 b-m1-p1-profile; do julia --project="$PKG" "julia/AgenticDS.jl/examples/$e/run.jl" | grep '^contract:'; done
echo "contract: b-m1 wrap-up OK"
