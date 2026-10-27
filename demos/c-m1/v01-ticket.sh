#!/usr/bin/env bash
# shellcheck disable=SC2016
# C-M1 video 1: the ticket's oracle, checksums then golden vs the raw data
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
(cd datasets/penguins && sha256sum -c SHA256SUMS)
Rscript -e 'library(agenticds)
g <- jsonlite::fromJSON("datasets/golden/p1.json")
raw <- read_penguins("datasets/penguins/penguins.csv"); d <- na_policy(raw)
cat(sprintf("raw rows %d, rows with no measurements %d, clean rows %d\n", nrow(raw), nrow(raw) - nrow(d), nrow(d)))
ns <- vapply(g$species, function(s) s$n, numeric(1)); print(ns)
cat(sprintf("golden n sums to %d\n", sum(ns)))
stopifnot(identical(as.integer(ns), as.integer(table(d$species)[names(ns)])), sum(ns) == nrow(d), sum(rowSums(is.na(raw[, 3:6])) == 4L) == nrow(raw) - nrow(d), nrow(raw) == 344L, nrow(d) == 342L)
cat("contract: c-m1 ticket oracle is consistent with the data (344 -> 342) OK\n")'
