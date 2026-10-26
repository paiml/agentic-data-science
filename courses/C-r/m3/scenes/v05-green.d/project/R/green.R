# v05 green: the p3 tests, on the real tree
h <- source("R/helpers.R")$value

run_scene <- function() {
  r <- testthat::test_dir(
    "tests/p3",
    reporter = "silent", stop_on_failure = FALSE
  )
  r <- as.data.frame(r)
  pass <- sum(r$passed)
  fail <- sum(r$failed)
  err <- sum(r$error)
  cat("passed", pass, "failed", fail, "errors", err, "\n")
  ok <- fail == 0 && err == 0 && pass > 0
  h$verdict("contract: c-m3 p3 tests green: ", ok)
}

if (sys.nframe() == 0) run_scene()
