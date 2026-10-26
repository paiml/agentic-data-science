# P2 (b): species model and fixed-fold CV.
# Usage: ADS_ROOT=/path/to/repo Rscript run.R
root <- Sys.getenv("ADS_ROOT", unset = ".")
library(agenticds)
d <- na_policy(read_penguins(
  file.path(root, "datasets", "penguins", "penguins.csv")
))
folds <- read_folds(
  file.path(root, "datasets", "fixtures", "folds.csv")
)
print(fit_lm_species(d))
cat("cv_rmse (ols):", cv_rmse(d, folds, FALSE), "\n")
cat("cv_rmse (species):", cv_rmse(d, folds, TRUE), "\n")
g <- jsonlite::fromJSON(
  file.path(root, "datasets", "golden", "p2.json")
)
stopifnot(isTRUE(all.equal(
  cv_rmse(d, folds, FALSE), g$cv_rmse$ols,
  tolerance = 1e-9
)))
cat("contract: ads-r-p2 cv matches golden/p2.json OK\n")
