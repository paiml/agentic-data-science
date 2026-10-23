#!/usr/bin/env bash
# B-M3 video 01-ticket: the P3 ticket and contract, the golden is consistent with the fixtures
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
(cd datasets/penguins && sha256sum -c SHA256SUMS)
grep -E '^# Tickets|^  description' contracts/ads-julia-p3-v1.yaml | cut -c 1-110
grep -E '^      - "(FIXED_SPLIT|FIXED_INIT|CONFUSION_TOTAL|CAN_FAIL)' contracts/ads-julia-p3-v1.yaml | cut -c 1-110
grep -E '^  - id: FALSIFY' contracts/ads-julia-p3-v1.yaml
julia --project="$PKG" -e '
using AgenticDS, DataFrames, JSON3
g = JSON3.read(read("datasets/golden/p3.json", String))
d = na_policy(read_penguins("datasets/penguins/penguins.csv"))
split = read_split("datasets/fixtures/split.csv")
cm = reduce(hcat, g.confusion)
println("clean rows ", nrow(d), "; split train ", count(==("train"), split), ", test ", count(==("test"), split))
println("golden confusion sums to ", sum(cm), "; diagonal ", sum(cm[i, i] for i in 1:3), "; accuracy ", g.accuracy)
println("golden k-means objective ", round(g.kmeans.objective; digits = 4), ", sizes ", collect(g.kmeans.cluster_sizes))
@assert length(split) == nrow(d) == 342 && count(==("test"), split) == sum(cm) == 85
@assert isapprox(g.accuracy, sum(cm[i, i] for i in 1:3) / sum(cm); atol = 1e-12)
@assert sum(g.kmeans.cluster_sizes) == nrow(d)
println("contract: b-m3 ticket oracle is consistent with the fixtures (257 train, 85 test) OK")'
