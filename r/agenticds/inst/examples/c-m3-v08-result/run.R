# C-M3 video 8: k-means from fixed centroids vs the golden result.
# Usage (from the repo root): source("this file")
library(agenticds)
d <- na_policy(read_penguins("datasets/penguins/penguins.csv"))
g <- jsonlite::fromJSON("datasets/golden/p3.json")
cen <- read_centroids("datasets/fixtures/centroids.csv")
km <- kmeans_fixed(d, cen)
sizes <- as.integer(table(km$cluster))
cat("cluster sizes:", sizes, "\n")
cat(sprintf("objective %.2f\n", km$objective))
cat(sprintf(
  "golden %s, objective %.2f\n",
  paste(g$kmeans$cluster_sizes, collapse = " "),
  g$kmeans$objective
))
stopifnot(
  identical(sizes, as.integer(g$kmeans$cluster_sizes)),
  abs(km$objective - g$kmeans$objective) < 1e-9
)
verdict("contract: ads-r-p3 k-means sizes, objective match OK")
