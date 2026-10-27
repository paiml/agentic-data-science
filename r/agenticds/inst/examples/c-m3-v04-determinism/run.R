# C-M3 video 4: fixed split, fixed centroids, identical runs.
# Usage (from the repo root): source("this file")
library(agenticds)
d <- na_policy(read_penguins("datasets/penguins/penguins.csv"))
s <- read_split("datasets/fixtures/split.csv")
cen <- read_centroids("datasets/fixtures/centroids.csv")
fit <- fit_species_clf(d[s == "train", ])
run <- function() {
  list(
    p = predict_species_clf(fit, d[s == "test", ]),
    km = kmeans_fixed(d, cen)
  )
}
a <- run()
b <- run()
cat("split:", paste(names(table(s)), table(s)), "\n")
cat("run 1 = run 2:", identical(a, b), "\n")
set.seed(1)
before <- .Random.seed
invisible(kmeans_fixed(d, cen))
cat("seed untouched:", identical(before, .Random.seed), "\n")
stopifnot(identical(a, b), identical(before, .Random.seed))
verdict("contract: ads-r-p3 deterministic, k-means draws no RNG OK")
