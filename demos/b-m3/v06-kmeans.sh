#!/usr/bin/env bash
# B-M3 video 06-kmeans: k-means from the fixed centroids.csv, objective and cluster sizes against the golden
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
cat datasets/fixtures/centroids.csv
julia --project="$PKG" -e '
using AgenticDS, DataFrames, JSON3
g = JSON3.read(read("datasets/golden/p3.json", String))
d = na_policy(read_penguins("datasets/penguins/penguins.csv"))
c = read_centroids("datasets/fixtures/centroids.csv")
km = kmeans_fixed(d, c)
sizes = [count(==(k), km.cluster) for k in 1:3]
one = kmeans_fixed(d, c; max_iter = 1)
println("objective after 1 pass ", round(one.objective; digits = 4), ", converged ", round(km.objective; digits = 4), ", golden ", round(g.kmeans.objective; digits = 4))
println("cluster sizes ", sizes, ", golden ", collect(g.kmeans.cluster_sizes))
@assert isapprox(km.objective, g.kmeans.objective; atol = 1e-6) && sizes == g.kmeans.cluster_sizes
@assert one.objective >= km.objective && sum(sizes) == 342
println("contract: b-m3 k-means from the fixed centroids matches objective 378.2936 and sizes 133/123/86 OK")'
