#!/usr/bin/env bash
# shellcheck disable=SC2016
# C-M2 video 5: tests green on the real tree; the numbers the ticket names
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
Rscript -e 'library(agenticds)
res <- as.data.frame(testthat::test_dir("r/agenticds/tests/testthat", filter = "p2", package = "agenticds", load_package = "installed", reporter = "silent", stop_on_failure = FALSE))
cat("expectations passed:", sum(res$passed), " failed:", sum(res$failed), " errors:", sum(res$error), "\n")
d <- na_policy(read_penguins("datasets/penguins/penguins.csv"))
b <- ols_closed_form(d$flipper_length_mm, d$body_mass_g)
m <- agenticds:::regression_metrics(d$body_mass_g, b[["intercept"]] + b[["slope"]] * d$flipper_length_mm)
cat(sprintf("slope %.2f  intercept %.0f  RMSE %.1f\n", b[["slope"]], b[["intercept"]], m$rmse))
print(fit_lm_species(d))
stopifnot(sum(res$failed) == 0, sum(res$error) == 0, sum(res$passed) > 0, isTRUE(abs(m$rmse - 393.1236) < 1e-3))
cat("contract: c-m2 tests green, numbers as ticketed OK\n")'
