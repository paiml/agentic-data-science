#!/usr/bin/env bash
# shellcheck disable=SC2016
# C-M4 video 1: the ticket's oracle, datasets verified then golden printed
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
(cd datasets/wine-quality && sha256sum -c SHA256SUMS)
Rscript -e 'library(agenticds)
g <- jsonlite::fromJSON("datasets/golden/p4.json")
df <- read_wine("datasets/wine-quality/winequality-red.csv", "datasets/wine-quality/winequality-white.csv")
cat(sprintf("golden: rows %d (train %d, test %d)  rmse %.4f  r2 %.4f\n", g$n_rows, g$n_train, g$n_test, g$rmse, g$r2))
cat(sprintf("data:   rows %d (red %d, white %d)\n", nrow(df), sum(df$color == "red"), sum(df$color == "white")))
stopifnot(g$n_rows == nrow(df), g$n_train + g$n_test == g$n_rows, g$n_test == floor(g$n_rows / 5))
cat("contract: c-m4 ticket oracle is consistent with the data (6497 rows, 1-in-5 test) OK\n")'
