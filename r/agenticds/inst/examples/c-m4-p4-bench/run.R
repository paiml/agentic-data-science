# P4 (b): dplyr vs data.table.
# Usage: ADS_ROOT=/path/to/repo Rscript run.R
root <- Sys.getenv("ADS_ROOT", unset = ".")
library(agenticds)
wine_dir <- file.path(root, "datasets", "wine-quality")
red <- file.path(wine_dir, "winequality-red.csv")
white <- file.path(wine_dir, "winequality-white.csv")
df <- read_wine(red, white)
stopifnot(isTRUE(all.equal(
  aggregate_dplyr(df), aggregate_data_table(df)
)))
print(bench_wine(df))
cat("contract: ads-r-p4 dplyr == data.table OK\n")

# The lesson figure: $ADS_OUT/plot.svg from the lesson dataset (no-op when ADS_OUT is unset).
invisible(agenticds::figure_demo("c-m4-p4-bench"))
