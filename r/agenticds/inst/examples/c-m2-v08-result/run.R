# C-M2 video 8: cross-validated error vs in-sample error.
# Usage (from the repo root): source("<this file>")
library(agenticds)
d <- na_policy(read_penguins("datasets/penguins/penguins.csv"))
f <- read_folds("datasets/fixtures/folds.csv")
b <- ols_closed_form(d$flipper_length_mm, d$body_mass_g)
yhat <- b[["intercept"]] + b[["slope"]] * d$flipper_length_mm
in_line <- regression_metrics(d$body_mass_g, yhat)$rmse
cv_line <- cv_rmse(d, f, FALSE)
cv_species <- cv_rmse(d, f, TRUE)
cat(sprintf("in-sample line:  %.1f g\n", in_line))
cat(sprintf("cross-val line:  %.1f g\n", cv_line))
cat(sprintf(
  "cross-val species: %.1f g (%.1f g better)\n",
  cv_species, cv_line - cv_species
))
g <- jsonlite::fromJSON("datasets/golden/p2.json")
stopifnot(
  cv_line > in_line, cv_species < cv_line,
  isTRUE(all.equal(cv_species, g$cv_rmse$species, tolerance = 1e-9))
)
verdict("contract: ads-r-p2 cv above in-sample, species better OK")
