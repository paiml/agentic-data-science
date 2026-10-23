#!/usr/bin/env bash
# B-M2 video 09-examples: the two P2 examples run end to end
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
for e in b-m2-p2-ols b-m2-p2-cv; do
  echo "--- examples/$e"
  out="$(julia --project="$PKG" "julia/AgenticDS.jl/examples/$e/run.jl" 2>/dev/null)"
  printf '%s\n' "$out" | sed -E 's/([0-9]+\.[0-9]{4})[0-9]+/\1/g'
  printf '%s\n' "$out" | grep -q '^contract: ads-julia-p2-v1 OK$'
done
echo "contract: b-m2 both P2 examples end on ads-julia-p2-v1 OK"
