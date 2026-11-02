# P1 (a): typed ingest and the missing-value policy.
# Usage: Rscript run.R path/to/penguins.csv
args <- commandArgs(trailingOnly = TRUE)
path <- if (length(args) >= 1) {
  args[[1]]
} else {
  file.path("datasets", "penguins", "penguins.csv")
}
library(agenticds)
penguins <- read_penguins(path)
clean <- na_policy(penguins)
cat(sprintf(
  "rows: %d, after NA policy: %d\n",
  nrow(penguins), nrow(clean)
))
stopifnot(nrow(penguins) == 344L, nrow(clean) == 342L)
cat("contract: ads-r-p1 ingest 344 -> 342 OK\n")

# The lesson figure: $ADS_OUT/plot.svg from the lesson dataset (no-op when ADS_OUT is unset).
invisible(agenticds::figure_demo("c-m1-p1"))
