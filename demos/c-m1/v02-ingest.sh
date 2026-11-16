#!/usr/bin/env bash
# shellcheck disable=SC2016
# C-M1 video 2: typed ingest and the NA policy
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
Rscript -e 'library(agenticds)
raw <- read_penguins("datasets/penguins/penguins.csv"); d <- na_policy(raw)
print(vapply(raw, function(x) class(x)[1], character(1)))
cat("NA per column (raw):\n"); print(colSums(is.na(raw)))
cat(sprintf("rows %d -> %d; sex still NA in %d clean rows (policy looks at measurements only)\n", nrow(raw), nrow(d), sum(is.na(d$sex))))
stopifnot(nrow(raw) == 344L, nrow(d) == 342L, sum(is.na(d$sex)) == 9L, is.numeric(raw$body_mass_g), is.integer(raw$year))
cat("contract: c-m1 typed ingest, 344 -> 342, sex NA kept OK\n")'
