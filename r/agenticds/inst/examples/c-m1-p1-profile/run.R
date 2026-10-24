# P1 (b): per-species count, mean and sample SD as JSON, matching datasets/golden/p1.json.
# Usage: Rscript run.R path/to/penguins.csv
args <- commandArgs(trailingOnly = TRUE)
path <- if (length(args) >= 1) args[[1]] else file.path("datasets", "penguins", "penguins.csv")
library(agenticds)
clean <- na_policy(read_penguins(path))
out <- summarise_by_species(clean)
cat(as.character(summary_json(out)), "\n")
golden <- jsonlite::fromJSON(file.path(dirname(dirname(path)), "golden", "p1.json"))
got <- jsonlite::fromJSON(as.character(summary_json(out)))
stopifnot(isTRUE(all.equal(got, golden, tolerance = 1e-9)))
cat("contract: ads-r-p1 profile matches golden/p1.json OK\n")
