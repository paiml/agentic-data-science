#!/usr/bin/env bash
# B-M4 video 08-bench: two aggregation engines agree first; timings are measured elsewhere, never printed here
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
julia --project="$PKG" -e '
using AgenticDS, DataFrames
d = read_wine("datasets/wine-quality/winequality-red.csv", "datasets/wine-quality/winequality-white.csv")
a = aggregate_groupby(d); b = aggregate_loop(d)
println(a); println(b)
@assert a.color == b.color && a.n == b.n == [1599, 4898]
@assert isapprox(a.mean_quality, b.mean_quality; atol = 1e-12)
t = bench_wine(d)
println("bench_wine engines: ", join(t.engine, ", "), "; every time positive: ", all(t.seconds .> 0))
@assert t.engine == ["groupby", "loop"] && all(t.seconds .> 0)
println("contract: b-m4 both engines agree before they are timed OK")'
