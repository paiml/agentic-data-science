# P4 (b): dplyr vs data.table. Usage: ADS_ROOT=/path/to/repo Rscript run.R
root <- Sys.getenv("ADS_ROOT", unset = ".")
library(agenticds)
red <- file.path(root, "datasets", "wine-quality", "winequality-red.csv")
white <- file.path(root, "datasets", "wine-quality", "winequality-white.csv")
df <- read_wine(red, white)
stopifnot(isTRUE(all.equal(aggregate_dplyr(df), aggregate_data_table(df))))
print(bench_wine(df))
cat("contract: ads-r-p4 dplyr == data.table OK\n")
