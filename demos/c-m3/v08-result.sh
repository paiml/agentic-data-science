#!/usr/bin/env bash
# shellcheck disable=SC2016
# C-M3 video 8: result, confusion matrix and cluster sizes
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
Rscript -e 'library(agenticds)
d <- na_policy(read_penguins("datasets/penguins/penguins.csv"))
g <- jsonlite::fromJSON("datasets/golden/p3.json")
cen <- read_centroids("datasets/fixtures/centroids.csv")
km <- kmeans_fixed(d, cen)
cat(sprintf("objective %.2f\n", km$objective)); print(table(km$cluster))
sizes <- as.integer(table(km$cluster))
cat("cluster sizes:", sizes, "\n")
stopifnot(identical(sizes, as.integer(g$kmeans$cluster_sizes)), abs(km$objective - g$kmeans$objective) < 1e-9)
cat("contract: c-m3 cluster sizes 133/123/86 and objective match golden OK\n")'
