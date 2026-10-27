# C-M2 video 1: the ticket's oracle is the golden file.
# Usage (from the repo root): source("<this file>")
library(agenticds)
g <- jsonlite::fromJSON("datasets/golden/p2.json")
want <- c("ols", "species_model", "metrics", "cv_rmse")
cat("golden/p2.json holds:", names(g), "\n")
cat(sprintf(
  "ols: intercept %.2f, slope %.2f\n",
  g$ols$intercept, g$ols$slope
))
cat(sprintf(
  "ols metrics: rmse %.1f, r2 %.3f\n",
  g$metrics$ols$rmse, g$metrics$ols$r2
))
stopifnot(
  all(want %in% names(g)),
  abs(g$ols$intercept - -5780.83) < 0.01,
  abs(g$ols$slope - 49.69) < 0.01,
  abs(g$cv_rmse$ols - 394.3) < 0.05
)
verdict("contract: ads-r-p2 ticket oracle present OK")
