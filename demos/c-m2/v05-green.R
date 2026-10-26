# C-M2 video 5 (native R): tests green on the real tree; the numbers the ticket names.
source("demos/native-lib.R")
src <- c(
  "res <- as.data.frame(testthat::test_dir(\"r/agenticds/tests/testthat\",",
  "  filter = \"p2\", package = \"agenticds\", load_package = \"source\",",
  "  reporter = \"silent\"))",
  "d <- na_policy(read_penguins(\"datasets/penguins/penguins.csv\"))",
  "b <- ols_closed_form(d$flipper_length_mm, d$body_mass_g)",
  "m <- regression_metrics(d$body_mass_g, b[[1]] + b[[2]] * d$flipper_length_mm)",
  "sum(res$failed) + sum(res$error) == 0 && abs(m$rmse - 393.1236) < 1e-3")
res <- as.data.frame(testthat::test_dir("r/agenticds/tests/testthat", filter = "p2", package = "agenticds",
  load_package = "source", reporter = "silent", stop_on_failure = FALSE))
d <- na_policy(read_penguins("datasets/penguins/penguins.csv"))
b <- ols_closed_form(d$flipper_length_mm, d$body_mass_g)
m <- regression_metrics(d$body_mass_g, b[[1]] + b[[2]] * d$flipper_length_mm)
nat_show("tests green on the real tree, and the numbers the ticket names", src)
nat_row("tests", sprintf("%d passed   %d failed   %d errors", sum(res$passed), sum(res$failed), sum(res$error)))
nat_row("slope / RMSE", sprintf("%.2f   %.1f", b[[2]], m$rmse))
nat_verdict(src[7], sum(res$failed) + sum(res$error) == 0 && abs(m$rmse - 393.1236) < 1e-3,
  "contract: c-m2 tests green, numbers as ticketed OK")
