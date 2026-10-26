# v10 wrapup: what the gate proved, two contracts
h <- source("R/helpers.R")$value

run_scene <- function() {
  d <- h$load_clean("data/penguins.csv")
  s <- h$read_split("data/split.csv")
  cen <- h$read_centroids("data/centroids.csv")
  g <- jsonlite::fromJSON("data/p3.json")
  fit <- h$fit_species_clf(d[s == "train", ])
  pred <- h$predict_species_clf(fit, d[s == "test", ])
  acc <- mean(d$species[s == "test"] == pred)
  km <- h$kmeans_fixed(d, cen)
  checks <- c(
    tree = abs(acc - g$accuracy) < 0.005,
    kmeans = abs(km$objective - g$kmeans$objective) < 1e-6
  )
  print(checks)
  h$verdict("contract: c-m3 wrap-up all OK: ", all(checks))
}

if (sys.nframe() == 0) run_scene()
