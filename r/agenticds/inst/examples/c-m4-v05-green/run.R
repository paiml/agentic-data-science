# C-M4 video 5: run the P4 tests and count what passed.
# Run from the repo root: source("<this file>")
library(agenticds)
r <- as.data.frame(testthat::test_dir(
  file.path("r", "agenticds", "tests", "testthat"),
  filter = "p4",
  package = "agenticds",
  load_package = "installed",
  reporter = "silent",
  stop_on_failure = FALSE
))
print(r$test)
cat(
  "passed:", sum(r$passed), " failed:", sum(r$failed),
  " errors:", sum(r$error), " skipped:", sum(r$skipped), "\n"
)
stopifnot(
  sum(r$passed) > 0, sum(r$failed) == 0,
  !any(r$error), sum(r$skipped) == 0
)
verdict("contract: ads-r-p4 tests green, none skipped OK")
