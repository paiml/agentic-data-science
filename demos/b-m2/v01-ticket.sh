#!/usr/bin/env bash
# B-M2 video 01-ticket: the P2 ticket's oracle, the contract file and the golden numbers
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
grep -E '^(# ads-julia-p2-v1|      (beta|cv_rmse|\|coef|\|cv_rmse) )' contracts/ads-julia-p2-v1.yaml
grep -E '^      - "(FIXED_FOLDS|NO_LEAKAGE|CAN_FAIL)' contracts/ads-julia-p2-v1.yaml
julia --project="$PKG" -e '
using JSON3
g = JSON3.read(read("datasets/golden/p2.json", String))
println("golden ols:     intercept ", round(g.ols.intercept; digits = 3), ", slope ", round(g.ols.slope; digits = 3))
println("golden r2:      ", round(g.metrics.ols.r2; digits = 4), " (flipper only), ", round(g.metrics.species.r2; digits = 4), " (with species)")
println("golden cv_rmse: ", round(g.cv_rmse.ols; digits = 3), " (flipper only), ", round(g.cv_rmse.species; digits = 3), " (with species)")
@assert round(g.cv_rmse.ols; digits = 3) == 394.313 && round(g.cv_rmse.species; digits = 3) == 376.638
@assert g.cv_rmse.species < g.cv_rmse.ols
println("contract: b-m2 ticket oracle: species model beats flipper-only out of fold, 376.638 < 394.313 OK")'
