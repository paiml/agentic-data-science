#!/usr/bin/env bash
# shellcheck disable=SC2016
# C-M3 video 1: the ticket's oracle
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
Rscript -e 'library(agenticds)
d <- na_policy(read_penguins("datasets/penguins/penguins.csv"))
g <- jsonlite::fromJSON("datasets/golden/p3.json")
print(g$confusion); print(g$kmeans)
stopifnot(abs(g$accuracy - 83/85) < 1e-12, sum(g$confusion) == 85, sum(g$kmeans$cluster_sizes) == 342)
cat("contract: c-m3 ticket oracle is self-consistent (83/85, 342 rows) OK\n")'
