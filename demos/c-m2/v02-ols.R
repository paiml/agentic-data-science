# C-M2 video 2 (native R): closed-form OLS, slope and R2 computed. Run from the repo root.
source("demos/native-lib.R")
src <- c(
  "d <- na_policy(read_penguins(\"datasets/penguins/penguins.csv\"))",
  "b <- ols_closed_form(d$flipper_length_mm, d$body_mass_g)",
  "m1 <- regression_metrics(d$body_mass_g,",
  "                         b[[\"intercept\"]] + b[[\"slope\"]] * d$flipper_length_mm)",
  "g <- jsonlite::fromJSON(\"datasets/golden/p2.json\")",
  "all.equal(m1$r2, g$metrics$ols$r2, tolerance = 1e-9)")
d <- na_policy(read_penguins("datasets/penguins/penguins.csv"))
b <- ols_closed_form(d$flipper_length_mm, d$body_mass_g)
m1 <- regression_metrics(d$body_mass_g, b[["intercept"]] + b[["slope"]] * d$flipper_length_mm)
g <- jsonlite::fromJSON("datasets/golden/p2.json")
nat_show("closed-form OLS: slope and R2, checked against the golden file", src)
nat_row("slope", sprintf("%.2f g/mm", b[["slope"]]))
nat_row("R2", sprintf("%.3f", m1$r2))
nat_verdict(src[6], isTRUE(all.equal(m1$r2, g$metrics$ols$r2, tolerance = 1e-9)),
  "contract: c-m2 slope and R2 computed, match golden OK")
