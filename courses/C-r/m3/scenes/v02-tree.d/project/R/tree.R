# v02 tree: species decision tree on the fixed split
h <- source("R/helpers.R")$value

run_scene <- function() {
  g <- jsonlite::fromJSON("data/p3.json")
  d <- h$load_clean("data/penguins.csv")
  s <- h$read_split("data/split.csv")
  tr <- d[s == "train", ]
  te <- d[s == "test", ]
  fit <- h$fit_species_clf(tr)
  pred <- h$predict_species_clf(fit, te)
  truth <- factor(te$species, levels = levels(pred))
  cm <- table(truth = truth, pred = pred)
  print(cm)
  acc <- mean(truth == pred)
  err <- sum(truth != pred)
  cat("accuracy", round(acc, 4), "errors", err, "\n")
  ok <- abs(acc - g$accuracy) < 0.005 &&
    all(cm == g$confusion)
  h$verdict("contract: c-m3 tree matches golden: ", ok)
}

if (sys.nframe() == 0) run_scene()
