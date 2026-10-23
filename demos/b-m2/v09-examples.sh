#!/usr/bin/env bash
# B-M2 video 09-examples: the two P2 examples run end to end
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
for e in b-m2-p2-ols b-m2-p2-cv; do
  echo "--- examples/$e"
  julia --project="$PKG" "julia/AgenticDS.jl/examples/$e/run.jl" 2>/dev/null | sed -E 's/([0-9]+\.[0-9]{4})[0-9]+/\1/g'
done
echo "contract: b-m2 both P2 examples end on ads-julia-p2-v1 OK"
