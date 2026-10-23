#!/usr/bin/env bash
# B-M4 video 09-examples: the two examples run; the bench timing line is dropped from the output
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
ex=julia/AgenticDS.jl/examples
julia --project="$PKG" "$ex/b-m4-p4-pipeline/run.jl" | grep -E '^(contract|<https)' | sed -n '1,3p'
b="$(julia --project="$PKG" "$ex/b-m4-p4-bench/run.jl")"
echo "$b" | grep -E '^(engine|contract)' | head -n 1
echo "$b" | tail -n 1 | grep -q '^contract: ads-julia-p4-v1 OK'
echo "contract: b-m4 both examples run and keep their contracts OK"
