#!/usr/bin/env bash
# B-M4 video 01-ticket: the ticket and its contract, golden counts vs the raw wine tables
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
(cd datasets/wine-quality && sha256sum -c SHA256SUMS)
sed -n '1,3p' contracts/ads-julia-p4-v1.yaml
julia --project="$PKG" -e '
using AgenticDS, DataFrames, JSON3
g = JSON3.read(read("datasets/golden/p4.json", String))
d = read_wine("datasets/wine-quality/winequality-red.csv", "datasets/wine-quality/winequality-white.csv")
println("rows ", nrow(d), " (red ", count(==("red"), d.color), ", white ", count(==("white"), d.color), ")")
println("golden: n_rows ", g.n_rows, ", n_train ", g.n_train, ", n_test ", g.n_test)
@assert nrow(d) == g.n_rows == 6497 && g.n_train + g.n_test == g.n_rows
@assert g.n_train == 5198 && g.n_test == 1299
println("contract: b-m4 ticket oracle is consistent with the data (6497 = 5198 + 1299) OK")'
