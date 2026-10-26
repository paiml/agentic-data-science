# v10 wrap-up: both p1 contracts, ingest and profile
h <- new.env()
sys.source("R/helpers.R", envir = h)

run_scene <- function() {
  stopifnot(h$check_sums("data"))
  raw <- h$read_penguins("data/penguins.csv")
  clean <- h$na_policy(raw)
  cat("ingest", nrow(raw), "->", nrow(clean), "\n")
  doc <- jsonlite::fromJSON(as.character(
    h$summary_json(h$summarise_by_species(clean))
  ))
  gold <- jsonlite::fromJSON("data/p1.json")
  gap <- max(abs(unlist(doc) - unlist(gold)))
  cat("profile gap to golden:", format(gap), "\n")
  res <- h$p1_suite()
  cat("p1 tests passed", sum(res), "of", length(res), "\n")
  ok <- nrow(clean) == 342 && gap < 1e-9 && all(res)
  h$verdict("contract: c-m1 wrap-up, both P1: ", ok)
}

if (sys.nframe() == 0) run_scene()
