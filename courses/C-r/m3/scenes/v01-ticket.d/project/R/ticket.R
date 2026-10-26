# v01 ticket: golden file p3 vs the cleaned penguins
h <- source("R/helpers.R")$value

run_scene <- function() {
  g <- jsonlite::fromJSON("data/p3.json")
  d <- h$load_clean("data/penguins.csv")
  hit <- sum(diag(g$confusion))
  all <- sum(g$confusion)
  acc <- hit / all
  cat("accuracy", round(acc, 4), "=", hit, "of", all, "\n")
  cat("cluster sizes", g$kmeans$cluster_sizes, "\n")
  cat("rows", nrow(d), "\n")
  ok <- abs(acc - g$accuracy) < 0.005 &&
    sum(g$kmeans$cluster_sizes) == nrow(d)
  h$verdict("contract: c-m3 ticket matches golden: ", ok)
}

if (sys.nframe() == 0) run_scene()
