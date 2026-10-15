# P1 (b): per-species count, mean and sample SD as JSON, matching datasets/golden/p1.json.
# Usage: Rscript run.R path/to/penguins.csv
args <- commandArgs(trailingOnly = TRUE)
path <- if (length(args) >= 1) args[[1]] else file.path("datasets", "penguins", "penguins.csv")
library(agenticds)
clean <- na_policy(read_penguins(path))
cat(as.character(summary_json(summarise_by_species(clean))), "\n")
