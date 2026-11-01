# C-M2 video 2: closed-form OLS; slope and R squared vs golden.
# Usage (from the repo root): source("<this file>")
library(agenticds)
d <- na_policy(read_penguins("datasets/penguins/penguins.csv"))
b <- ols_closed_form(d$flipper_length_mm, d$body_mass_g)
m <- regression_metrics(
  d$body_mass_g,
  b[["intercept"]] + b[["slope"]] * d$flipper_length_mm
)
g <- jsonlite::fromJSON("datasets/golden/p2.json")
cat(sprintf("slope %.2f g/mm\n", b[["slope"]]))
cat(sprintf("R squared %.3f\n", m$r2))
stopifnot(
  isTRUE(all.equal(b[["slope"]], g$ols$slope, tolerance = 1e-9)),
  isTRUE(all.equal(m$r2, g$metrics$ols$r2, tolerance = 1e-9))
)
verdict("contract: ads-r-p2 slope and R2 match golden OK")
