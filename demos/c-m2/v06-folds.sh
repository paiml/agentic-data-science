#!/usr/bin/env bash
# shellcheck disable=SC2016
# C-M2 video 6: fixed folds assigned by row index give the same CV twice
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
Rscript -e 'library(agenticds)
d <- na_policy(read_penguins("datasets/penguins/penguins.csv"))
f <- read_folds("datasets/fixtures/folds.csv")
print(table(f))
stopifnot(identical(as.integer(f[1:10]), as.integer(rep(1:5, 2))))
cat("first ten rows go to folds:", f[1:10], "\n")
a <- c(cv_rmse(d, f, FALSE), cv_rmse(d, f, TRUE)); b <- c(cv_rmse(d, f, FALSE), cv_rmse(d, f, TRUE))
cat(sprintf("cv_rmse line %.1f species %.1f (run 1)\ncv_rmse line %.1f species %.1f (run 2)\n", a[1], a[2], b[1], b[2]))
stopifnot(identical(a, b))
cat("contract: c-m2 fixed folds repeatable OK\n")'
