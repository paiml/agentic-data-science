# v05: back on the real tree, the P2 tests run green
h <- new.env()
sys.source("R/helpers.R", envir = h)

run_scene <- function() {
  res <- as.data.frame(testthat::test_dir(
    "tests/p2",
    reporter = "silent", stop_on_failure = FALSE
  ))
  cat(
    "passed", sum(res$passed), "failed", sum(res$failed),
    "errors", sum(res$error), "\n"
  )
  d <- h$load_clean("data/penguins.csv")
  fit <- h$fit_line(d)
  m <- h$regression_metrics(d$body_mass_g, fit$fitted)
  cat(sprintf(
    "slope %.2f  RMSE %.1f\n", fit$b[["slope"]], m$rmse
  ))
  ok <- sum(res$failed) == 0 && sum(res$error) == 0 &&
    abs(m$rmse - 393.1236) < 0.001
  h$verdict("tests green, numbers as ticketed", ok)
}

if (sys.nframe() == 0 && !run_scene()) quit(status = 1)
