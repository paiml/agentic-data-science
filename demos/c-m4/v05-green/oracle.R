# green: run the p4 tests and count what passed
r <- as.data.frame(testthat::test_dir(
  "r/agenticds/tests/testthat", filter = "p4", package = "agenticds",
  load_package = "source", reporter = "silent", stop_on_failure = FALSE))
r$test
colSums(r[c("passed", "failed", "skipped")])
ok <- sum(r$passed) > 0 && sum(r$failed) == 0 &&
  !any(r$error) && sum(r$skipped) == 0
cat(cli::col_green(cli::style_bold(ok)), "\n")
