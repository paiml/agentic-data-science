#!/usr/bin/env bash
# B-M1 video 06-json: the profile example prints its table and matches the golden
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
julia --project="$PKG" julia/AgenticDS.jl/examples/b-m1-p1-profile/run.jl | tail -n 12
julia --project="$PKG" julia/AgenticDS.jl/examples/b-m1-p1-profile/run.jl | grep -q '^contract: ads-julia-p1-v1 OK$'
echo "contract: b-m1 profile equals the golden OK"
