#!/usr/bin/env bash
# shellcheck disable=SC2016
# C-M3 video 4: fixed split and centroids make every run identical
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
Rscript -e 'library(agenticds)
d <- na_policy(read_penguins("datasets/penguins/penguins.csv"))
g <- jsonlite::fromJSON("datasets/golden/p3.json")
s <- read_split("datasets/fixtures/split.csv"); cen <- read_centroids("datasets/fixtures/centroids.csv")
print(table(s)); print(cen)
run <- function() {
  fit <- fit_species_clf(d[s == "train", ])
  list(pred = predict_species_clf(fit, d[s == "test", ]), km = kmeans_fixed(d, cen))
}
a <- run(); b <- run()
set.seed(1); seed_before <- get(".Random.seed", globalenv())
invisible(kmeans_fixed(d, cen))
stopifnot(identical(a$pred, b$pred), identical(a$km$cluster, b$km$cluster), identical(a$km$objective, b$km$objective))
seed_after <- get(".Random.seed", globalenv())
stopifnot(identical(seed_before, seed_after))
cat("two runs identical; k-means consumed no random numbers\n")
cat("contract: c-m3 deterministic; k-means consumes no RNG OK\n")'
