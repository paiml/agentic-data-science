#!/usr/bin/env bash
# shellcheck disable=SC2016
# C-M3 video 1: the ticket's oracle
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
Rscript -e 'library(agenticds)
d <- na_policy(read_penguins("datasets/penguins/penguins.csv"))
g <- jsonlite::fromJSON("datasets/golden/p3.json")
print(g$confusion); print(g$kmeans)
cat(sprintf("accuracy %.4f = %d/%d; clean rows %d\n", g$accuracy, sum(diag(g$confusion)), sum(g$confusion), nrow(d)))
stopifnot(isTRUE(abs(sum(diag(g$confusion)) / sum(g$confusion) - g$accuracy) < 1e-12), isTRUE(nrow(d) == sum(g$kmeans$cluster_sizes)))
cat("contract: c-m3 ticket oracle is consistent with the data (accuracy, 342 rows) OK\n")'
