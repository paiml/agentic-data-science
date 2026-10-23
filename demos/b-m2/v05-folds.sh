#!/usr/bin/env bash
# B-M2 video 05-folds: fixed folds, out-of-fold predictions, cv_rmse against the golden
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
julia --project="$PKG" -e '
using AgenticDS, DataFrames, JSON3, Logging; global_logger(NullLogger())
d = na_policy(read_penguins("datasets/penguins/penguins.csv"))
folds = read_folds("datasets/fixtures/folds.csv")
println("fold sizes: ", [count(==(k), folds) for k in 1:5], " (read from a file, never from an RNG)")
ols = cv_rmse(d, folds, false); sp = cv_rmse(d, folds, true)
b = ols_closed_form(d.flipper_length_mm, d.body_mass_g)
insample = regression_metrics(d.body_mass_g, b.intercept .+ b.slope .* d.flipper_length_mm).rmse
println("in-sample rmse (flipper only): ", round(insample; digits = 3))
println("cv_rmse flipper only:          ", round(ols; digits = 3))
println("cv_rmse with species:          ", round(sp; digits = 3))
g = JSON3.read(read("datasets/golden/p2.json", String))
@assert sort(unique(folds)) == 1:5 && length(folds) == nrow(d)
@assert insample < ols
@assert isapprox(ols, g.cv_rmse.ols; atol = 1e-6) && isapprox(sp, g.cv_rmse.species; atol = 1e-6)
@assert round(ols; digits = 3) == 394.313 && round(sp; digits = 3) == 376.638
println("contract: b-m2 fixed-fold cv_rmse 394.313 and 376.638 match the golden, above the in-sample error OK")'
