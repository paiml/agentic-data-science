# C-M1 video 6: the profile as JSON, equal to the golden file.
# Run from the repo root: source("<this file>")
library(agenticds)
clean <- na_policy(read_penguins("datasets/penguins/penguins.csv"))
json <- as.character(summary_json(summarise_by_species(clean)))
cat(tail(strsplit(json, "\n")[[1]], 22), sep = "\n")
golden <- jsonlite::fromJSON("datasets/golden/p1.json")
stopifnot(isTRUE(all.equal(
  jsonlite::fromJSON(json), golden, tolerance = 1e-9
)))
verdict("contract: ads-r-p1 profile matches golden/p1.json OK")
