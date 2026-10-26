# v03 red: an oracle must be able to fail (planted bug)
h <- source("R/helpers.R")$value

run_scene <- function() {
  d <- h$load_clean("data/penguins.csv")
  s <- h$read_split("data/split.csv")
  tr <- d[s == "train", ]
  te <- d[s == "test", ]
  fit <- h$fit_species_clf(tr)
  pred <- h$predict_species_clf(fit, te)
  truth <- factor(te$species, levels = levels(pred))
  g <- jsonlite::fromJSON("data/p3.json")$accuracy
  b <- mean(truth != pred)
  cat("golden", round(g, 4), "broken", round(b, 4), "\n")
  r <- all.equal(b, g)
  cat(cli::col_red(r), "\n")
  h$verdict("contract: c-m3 bug caught: ", !isTRUE(r))
}

if (sys.nframe() == 0) run_scene()
