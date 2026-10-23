#!/usr/bin/env bash
# B-M2 video 02-design: ingest the clean rows and build the design matrices
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
julia --project="$PKG" -e '
using AgenticDS, DataFrames
d = na_policy(read_penguins("datasets/penguins/penguins.csv"))
x = d.flipper_length_mm; y = d.body_mass_g
X = [ones(length(x)) x]
println("clean rows ", nrow(d), ", design matrix [1 x] is ", size(X, 1), " x ", size(X, 2))
println("first three rows of X: ", X[1:3, :])
println("first three masses:    ", y[1:3])
S = AgenticDS.species_design(d)
println("species design columns: ", names(S))
println("dummy sums (Chinstrap, Gentoo): ", Int(sum(S.speciesChinstrap)), ", ", Int(sum(S.speciesGentoo)), "; Adelie is the baseline: ", count(==("Adelie"), d.species))
@assert size(X) == (342, 2) && all(X[:, 1] .== 1.0)
@assert Int(sum(S.speciesChinstrap)) == 68 && Int(sum(S.speciesGentoo)) == 123 && count(==("Adelie"), d.species) == 151
println("contract: b-m2 design matrices: 342 x 2 for OLS, two species dummies with Adelie as baseline OK")'
