#!/usr/bin/env bash
# B-M4 video 09-examples: the two examples run; the bench timing line is dropped from the output
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
ex=julia/AgenticDS.jl/examples
p="$(julia --project="$PKG" "$ex/b-m4-p4-pipeline/run.jl")"
echo "$p" | grep -E '^(<https|  ads:rows)'
echo "$p" | grep -q '^contract: ads-julia-p4-v1 OK$'
b="$(julia --project="$PKG" "$ex/b-m4-p4-bench/run.jl")"
echo "$b" | grep -q '^contract: ads-julia-p4-v1 OK$'
echo "contract: b-m4 both examples run and keep their contracts OK"
