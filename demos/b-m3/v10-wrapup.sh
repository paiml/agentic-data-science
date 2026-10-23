#!/usr/bin/env bash
# B-M3 video 10-wrapup: wrap-up, both P3 contracts and the golden numbers, read and asserted
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
for e in b-m3-p3-tree b-m3-p3-kmeans; do julia --project="$PKG" "julia/AgenticDS.jl/examples/$e/run.jl" | grep '^contract:'; done
julia --project="$PKG" -e '
using AgenticDS, JSON3
g = JSON3.read(read("datasets/golden/p3.json", String))
cm = [collect(r) for r in g.confusion]
sizes = collect(g.kmeans.cluster_sizes)
println("golden accuracy ", g.accuracy, ", confusion ", cm, ", k-means ", round(g.kmeans.objective; digits = 4), " / ", sizes)
@assert g.accuracy == 0.976470588235294 && cm == [[37, 0, 0], [0, 16, 1], [0, 1, 30]]
@assert round(g.kmeans.objective; digits = 4) == 378.2936 && sizes == [133, 123, 86]
println("contract: b-m3 wrap-up OK")'
