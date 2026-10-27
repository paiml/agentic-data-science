# C-M3 video 4: fixed split, fixed centroids, identical runs.
# Usage (from the repo root): source("this file")
raw <- agenticds::read_penguins("datasets/penguins/penguins.csv")
d <- agenticds::na_policy(raw)
s <- agenticds::read_split("datasets/fixtures/split.csv")
cen <- agenticds::read_centroids("datasets/fixtures/centroids.csv")
run <- function() {
  fit <- agenticds::fit_species_clf(d[s == "train", ])
  p <- agenticds::predict_species_clf(fit, d[s == "test", ])
  before <- get0(".Random.seed", globalenv())
  km <- agenticds::kmeans_fixed(d, cen)
  after <- get0(".Random.seed", globalenv())
  list(p = p, km = km, seed_kept = identical(before, after))
}
a <- run()
b <- run()
cat("split:", paste(names(table(s)), table(s)), "\n")
cat("run 1 = run 2:", identical(a, b), "\n")
cat("seed untouched:", a$seed_kept && b$seed_kept, "\n")
stopifnot(identical(a, b), a$seed_kept, b$seed_kept)
agenticds::verdict(
  "contract: ads-r-p3 deterministic, k-means draws no RNG OK"
)
