# C-M1 video 5: the p1 tests pass, with no errors or skips.
# Run from the repo root: source("<this file>")
library(agenticds)
tdir <- "r/agenticds/tests/testthat"
res <- as.data.frame(testthat::test_file(
  file.path(tdir, "test-p1.R"), reporter = "silent",
  stop_on_failure = FALSE, package = "agenticds"
))
cat(sprintf(
  "passed %d, failed %d, errored %d, skipped %d\n",
  sum(res$passed), sum(res$failed), sum(res$error), sum(res$skipped)
))
cat(res$test, sep = "\n")
stopifnot(
  sum(res$passed) > 0, sum(res$failed) == 0,
  !any(res$error), !any(res$skipped)
)
verdict("contract: ads-r-p1 tests green OK")
