#!/usr/bin/env bash
# B-M4 video 02-ingest: read_wine, then validate_wine and its three refusals
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
julia --project="$PKG" -e '
using AgenticDS, DataFrames
d = read_wine("datasets/wine-quality/winequality-red.csv", "datasets/wine-quality/winequality-white.csv")
println("read ", nrow(d), " rows; first colour ", d.color[1], ", last colour ", d.color[end])
@assert validate_wine(d) === d
println("validate_wine: clean table passes")
m = copy(d; copycols = true); allowmissing!(m, :alcohol); m.alcohol[3] = missing
hi = copy(d); hi.quality[2] = 11
rose = copy(d); rose.color[2] = "rose"
msgs = String[]
for (name, bad) in (("missing value", m), ("quality 11", hi), ("colour rose", rose))
    try validate_wine(bad); push!(msgs, "NOT REFUSED")
    catch e; push!(msgs, e.msg); println(name, " -> ArgumentError: ", e.msg) end
end
@assert msgs == ["wine data has missing values", "quality outside 0..10", "unknown color"]
println("contract: b-m4 validate_wine refuses missing values, quality outside 0..10 and unknown colours OK")'
