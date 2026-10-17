# P4 (a): Wine Quality pipeline. Usage: ADS_ROOT=/path/to/repo Rscript run.R
root <- Sys.getenv("ADS_ROOT", unset = ".")
library(agenticds)
red <- file.path(root, "datasets", "wine-quality", "winequality-red.csv")
white <- file.path(root, "datasets", "wine-quality", "winequality-white.csv")
res <- pipeline_wine(red, white)
cat(sprintf("rows %d (train %d, test %d)\n", res$n_rows, res$n_train, res$n_test))
cat(sprintf("rmse %.6f  r2 %.6f\n", res$rmse, res$r2))
report_ttl(res, file.path(tempdir(), "wine-report-artifact.ttl"))
