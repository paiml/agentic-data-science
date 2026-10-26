# v04 determinism: same inputs, same answer, no random draw
h <- source("R/helpers.R")$value

run_scene <- function() {
  d <- h$load_clean("data/penguins.csv")
  s <- h$read_split("data/split.csv")
  cen <- h$read_centroids("data/centroids.csv")
  run <- function() {
    fit <- h$fit_species_clf(d[s == "train", ])
    list(
      pred = h$predict_species_clf(fit, d[s == "test", ]),
      km = h$kmeans_fixed(d, cen)
    )
  }
  same <- identical(run(), run())
  set.seed(1)
  seed <- globalenv()$.Random.seed
  h$kmeans_fixed(d, cen)
  kept <- identical(seed, globalenv()$.Random.seed)
  cat("same twice:", same, "seed kept:", kept, "\n")
  h$verdict("contract: c-m3 deterministic: ", same && kept)
}

if (sys.nframe() == 0) run_scene()
