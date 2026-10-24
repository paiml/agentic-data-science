#!/usr/bin/env bash
# B-M1 video 6: the profile example prints its table and matches the golden
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
out="$(julia --project="$PKG" julia/AgenticDS.jl/examples/b-m1-p1-profile/run.jl)"
printf '%s\n' "$out" | tail -n 12
printf '%s\n' "$out" | grep -q '^contract: ads-julia-p1-v1 OK$'
echo "contract: b-m1 profile equals the golden OK"
