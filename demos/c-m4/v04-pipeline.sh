#!/usr/bin/env bash
# shellcheck disable=SC2016
# C-M4 video 4: pipeline_wine, sizes and held-out error computed
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
Rscript -e 'library(agenticds)
res <- pipeline_wine("datasets/wine-quality/winequality-red.csv", "datasets/wine-quality/winequality-white.csv")
cat(sprintf("rows %d  train %d  test %d\nrmse %.4f  r2 %.4f\n", res$n_rows, res$n_train, res$n_test, res$rmse, res$r2))
print(unlist(res$mean_quality_by_color))
g <- jsonlite::fromJSON("datasets/golden/p4.json")
stopifnot(res$n_train + res$n_test == res$n_rows, isTRUE(all.equal(res$rmse, g$rmse, tolerance = 1e-9)), isTRUE(all.equal(res$r2, g$r2, tolerance = 1e-9)))
cat("contract: c-m4 pipeline rmse and r2 equal the golden OK\n")'
