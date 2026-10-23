#!/usr/bin/env bash
# B-M3 video 09-examples: the two P3 examples print their results and keep their contract
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
for e in b-m3-p3-tree b-m3-p3-kmeans; do
  echo "--- $e"
  out="$(julia --project="$PKG" "julia/AgenticDS.jl/examples/$e/run.jl")"
  printf '%s\n' "$out"
  printf '%s\n' "$out" | grep -q '^contract: ads-julia-p3-v1 OK$'
done
echo "contract: b-m3 both P3 examples equal the golden OK"
