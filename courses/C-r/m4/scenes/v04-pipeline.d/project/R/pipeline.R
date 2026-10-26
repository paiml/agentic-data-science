# c-m4 v04: pipeline_wine, split sizes and rmse
h <- new.env()
sys.source("R/helpers.R", h)
library(agenticds)

run_scene <- function() {
  res <- pipeline_wine(h$wine("red"), h$wine("white"))
  g <- jsonlite::fromJSON("data/p4.json")
  cat("rows:", res$n_rows, "\n")
  cat("train:", res$n_train, " test:", res$n_test, "\n")
  cat("rmse:", round(res$rmse, 6), "\n")
  cat("r2:  ", round(res$r2, 6), "\n")
  ok <- res$n_test == g$n_test &&
    abs(res$rmse - g$rmse) < 0.005 &&
    abs(res$r2 - g$r2) < 0.005
  h$verdict(ok, "pipeline matches the golden ticket")
}

if (sys.nframe() == 0) run_scene()
