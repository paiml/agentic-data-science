#!/usr/bin/env bash
# B-M4 video 04-pipeline: pipeline_wine fits on the train rows; RMSE and R2 match the golden file
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
julia --project="$PKG" -e '
using AgenticDS, JSON3, Printf
g = JSON3.read(read("datasets/golden/p4.json", String))
r = pipeline_wine("datasets/wine-quality/winequality-red.csv", "datasets/wine-quality/winequality-white.csv")
@printf("n_rows %d, n_train %d, n_test %d\n", r["n_rows"], r["n_train"], r["n_test"])
@printf("rmse %.9f (golden %.9f)\n", r["rmse"], g.rmse)
@printf("r2   %.9f (golden %.9f)\n", r["r2"], g.r2)
@assert r["n_rows"] == g.n_rows && r["n_train"] == g.n_train && r["n_test"] == g.n_test
@assert isapprox(r["rmse"], g.rmse; atol = 1e-6) && isapprox(r["r2"], g.r2; atol = 1e-6)
println("contract: b-m4 pipeline_wine matches the golden RMSE and R2 within 1e-6 OK")'
