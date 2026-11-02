# P1 (b): per-species count, mean and sample SD as JSON, matching
# the golden file datasets/golden/p1.json.
# Usage: Rscript run.R path/to/penguins.csv
args <- commandArgs(trailingOnly = TRUE)
path <- if (length(args) >= 1) {
  args[[1]]
} else {
  file.path("datasets", "penguins", "penguins.csv")
}
library(agenticds)
clean <- na_policy(read_penguins(path))
out <- summarise_by_species(clean)
cat(as.character(summary_json(out)), "\n")
golden <- jsonlite::fromJSON(
  file.path(dirname(dirname(path)), "golden", "p1.json")
)
got <- jsonlite::fromJSON(as.character(summary_json(out)))
stopifnot(isTRUE(all.equal(got, golden, tolerance = 1e-9)))
cat("contract: ads-r-p1 profile matches golden/p1.json OK\n")

# The lesson figure: $ADS_OUT/plot.svg from the lesson dataset (no-op when ADS_OUT is unset).
invisible(agenticds::figure_demo("c-m1-p1-profile"))
