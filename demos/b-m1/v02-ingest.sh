#!/usr/bin/env bash
# B-M1 video 02-ingest: typed ingest and the NA policy
# shellcheck source=../lib-julia.sh
source "$(dirname "$0")/../lib-julia.sh"
julia --project="$PKG" -e '
using AgenticDS, DataFrames
raw = read_penguins("datasets/penguins/penguins.csv"); d = na_policy(raw)
for c in names(raw); println(rpad(c, 18), eltype(raw[!, c])); end
println("missing per column (raw): ", sort([c => count(ismissing, raw[!, c]) for c in names(raw) if any(ismissing, raw[!, c])]))
println("rows ", nrow(raw), " -> ", nrow(d), "; sex still missing in ", count(ismissing, d.sex), " clean rows (policy looks at measurements only)")
@assert nrow(raw) == 344 && nrow(d) == 342 && count(ismissing, d.sex) == 9
@assert eltype(d.body_mass_g) == Float64 && eltype(raw.year) == Int
println("contract: b-m1 typed ingest, 344 -> 342, sex missing kept OK")'
