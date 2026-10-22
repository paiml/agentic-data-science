#!/usr/bin/env bash
# shellcheck disable=SC2016
# C-M4 video 8: dplyr and data.table agree exactly; timings are shown, never asserted
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
Rscript -e 'library(agenticds)
df <- read_wine("datasets/wine-quality/winequality-red.csv", "datasets/wine-quality/winequality-white.csv")
a <- aggregate_dplyr(df); b <- aggregate_data_table(df)
print(a); print(b)
stopifnot(identical(a$color, b$color), isTRUE(all.equal(a$mean_quality, b$mean_quality, tolerance = 1e-12)), identical(a$n, b$n))
cat("same answer; timings below vary run to run and are not asserted\n")
print(bench_wine(df, reps = 5L))
cat("contract: c-m4 dplyr == data.table OK\n")'
