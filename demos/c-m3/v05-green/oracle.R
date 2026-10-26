# the p3 tests, run on the real tree
res <- as.data.frame(testthat::test_dir("r/agenticds/tests/testthat",
  filter = "p3", package = "agenticds", load_package = "source",
  reporter = "silent", stop_on_failure = FALSE))
c(passed = sum(res$passed), failed = sum(res$failed), err = sum(res$error))
ok <- sum(res$failed) + sum(res$error) == 0 && sum(res$passed) > 0
cat(cli::col_green(cli::style_bold(ok)), "\n")
