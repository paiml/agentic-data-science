# C-M2 video 5: the P2 tests are green; the ticket's numbers.
# Usage (from the repo root): source("<this file>")
library(agenticds)
res <- as.data.frame(testthat::test_dir(
  "r/agenticds/tests/testthat",
  filter = "p2", package = "agenticds",
  load_package = "source", reporter = "silent",
  stop_on_failure = FALSE
))
d <- na_policy(read_penguins("datasets/penguins/penguins.csv"))
b <- ols_closed_form(d$flipper_length_mm, d$body_mass_g)
yhat <- b[["intercept"]] + b[["slope"]] * d$flipper_length_mm
m <- regression_metrics(d$body_mass_g, yhat)
cat(sprintf(
  "tests: %d passed, %d failed, %d errors\n",
  sum(res$passed), sum(res$failed), sum(res$error)
))
cat(sprintf("slope %.2f, rmse %.1f\n", b[["slope"]], m$rmse))
stopifnot(
  sum(res$failed) + sum(res$error) == 0,
  abs(m$rmse - 393.1236) < 1e-3
)
verdict("contract: ads-r-p2 tests green, numbers as ticketed OK")
