#!/usr/bin/env bash
# shellcheck disable=SC2016
# C-M4 video 5: the p4 tests pass, no errors or skips
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
Rscript -e 'r <- as.data.frame(testthat::test_dir("r/agenticds/tests/testthat", filter = "p4", package = "agenticds", load_package = "source", reporter = "silent", stop_on_failure = FALSE))
cat("passed:", sum(r$passed), " failed:", sum(r$failed), " errored:", sum(r$error), " skipped:", sum(r$skipped), "\n")
print(r$test)
stopifnot(sum(r$passed) > 0, sum(r$failed) == 0, sum(r$error) == 0, sum(r$skipped) == 0)
cat("contract: c-m4 p4 tests green OK\n")'
