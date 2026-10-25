#!/usr/bin/env bash
# B-M1 video 04-profile: per-species n, mean and sample sd, checked against the n-1 formula
# shellcheck source=../lib-julia.sh
source "$(dirname "$0")/../lib-julia.sh"
julia --project="$PKG" -e '
using AgenticDS, DataFrames, Statistics
d = na_policy(read_penguins("datasets/penguins/penguins.csv"))
s = summarise_by_species(d)
show(stdout, MIME("text/plain"), s[:, [:species, :n, :body_mass_g_mean, :body_mass_g_sd]]); println()
x = d.body_mass_g[d.species .== "Gentoo"]
hand = sqrt(sum((x .- mean(x)) .^ 2) / (length(x) - 1)); pop = sqrt(sum((x .- mean(x)) .^ 2) / length(x))
println("Gentoo body mass sd: summarise ", s.body_mass_g_sd[s.species .== "Gentoo"][1], "  n-1 by hand ", hand, "  n (population) ", pop)
@assert s.n == [151, 68, 123]
@assert isapprox(s.body_mass_g_sd[s.species .== "Gentoo"][1], hand; atol = 1e-12) && abs(hand - pop) > 1e-3
println("contract: b-m1 counts 151/68/123 and sd uses n-1 OK")'
