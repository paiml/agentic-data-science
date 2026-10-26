# c-m4 v05: the checks pass, green
h <- new.env()
sys.source("R/helpers.R", h)
library(agenticds)

run_scene <- function() {
  res <- pipeline_wine(h$wine("red"), h$wine("white"))
  g <- jsonlite::fromJSON("data/p4.json")
  checks <- list(
    rows = res$n_rows == g$n_rows,
    split = res$n_test == g$n_test,
    rmse = abs(res$rmse - g$rmse) < 0.005,
    r2 = abs(res$r2 - g$r2) < 0.005
  )
  h$verdict(h$report(checks), "all four checks pass")
}

if (sys.nframe() == 0) run_scene()
