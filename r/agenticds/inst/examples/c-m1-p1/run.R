# P1: ingest and profile Palmer Penguins.
# Usage: Rscript run.R path/to/penguins.csv
args <- commandArgs(trailingOnly = TRUE)
path <- if (length(args) >= 1) args[[1]] else file.path("datasets", "penguins", "penguins.csv")
library(agenticds)
penguins <- read_penguins(path)
clean <- na_policy(penguins)
cat(sprintf("rows: %d, after NA policy: %d\n", nrow(penguins), nrow(clean)))
cat(as.character(summary_json(summarise_by_species(clean))), "\n")
