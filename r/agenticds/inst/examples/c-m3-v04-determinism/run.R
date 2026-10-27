# C-M3 video 4: fixed split, fixed centroids, identical runs.
# Usage (from the repo root): source("this file")
raw <- agenticds::read_penguins("datasets/penguins/penguins.csv")
d <- agenticds::na_policy(raw)
s <- agenticds::read_split("datasets/fixtures/split.csv")
cen <- agenticds::read_centroids("datasets/fixtures/centroids.csv")
fit <- agenticds::fit_species_clf(d[s == "train", ])
run <- function() {
  list(
    p = agenticds::predict_species_clf(fit, d[s == "test", ]),
    km = agenticds::kmeans_fixed(d, cen)
  )
}
verdict <- agenticds::verdict
a <- run()
b <- run()
cat("split:", paste(names(table(s)), table(s)), "\n")
cat("run 1 = run 2:", identical(a, b), "\n")
before <- get0(".Random.seed", globalenv())
invisible(agenticds::kmeans_fixed(d, cen))
same <- identical(before, get0(".Random.seed", globalenv()))
cat("seed untouched:", same, "\n")
stopifnot(identical(a, b), same)
verdict("contract: ads-r-p3 deterministic, k-means draws no RNG OK")
