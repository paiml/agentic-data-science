# v08 result: k-means from the fixed centroids vs golden
h <- source("R/helpers.R")$value

run_scene <- function() {
  d <- h$load_clean("data/penguins.csv")
  cen <- h$read_centroids("data/centroids.csv")
  g <- jsonlite::fromJSON("data/p3.json")$kmeans
  km <- h$kmeans_fixed(d, cen)
  sizes <- tabulate(km$cluster, nbins = nrow(cen))
  cat("sizes", sizes, "\n")
  cat("objective", round(km$objective, 2), "\n")
  cat("golden", round(g$objective, 2), "\n")
  ok <- identical(sizes, as.integer(g$cluster_sizes)) &&
    abs(km$objective - g$objective) < 1e-9
  h$verdict("contract: c-m3 kmeans matches golden: ", ok)
}

if (sys.nframe() == 0) run_scene()
