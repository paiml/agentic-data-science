#!/usr/bin/env bash
# B-M1 video 09-parse: a malformed number is never a silent string
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
out="$(mktemp -d)"
trap 'rm -rf -- "${out:?}"' EXIT
head -n 1 datasets/penguins/penguins.csv > "$out/bad.csv"
echo "Adelie,Torgersen,39.1,18.7,181,heavy,male,2007" >> "$out/bad.csv"
echo "Adelie,Torgersen,39.5,17.4,186,3800,female,2007" >> "$out/bad.csv"
julia --project="$PKG" -e '
using AgenticDS, DataFrames
d = read_penguins(ARGS[1])
show(stdout, MIME("text/plain"), d[:, [:species, :body_mass_g]]); println()
@assert eltype(d.body_mass_g) == Union{Missing,Float64} && ismissing(d.body_mass_g[1]) && nrow(na_policy(d)) == 1
println("contract: b-m1 malformed number becomes missing and is dropped by the policy OK")' "$out/bad.csv" 2>&1 | grep -v '@ CSV' | tail -n 12
