# v06 json: the profile as JSON, equal to the golden
h <- new.env()
sys.source("R/helpers.R", envir = h)

run_scene <- function() {
  stopifnot(h$check_sums("data"))
  d <- h$na_policy(h$read_penguins("data/penguins.csv"))
  js <- h$summary_json(h$summarise_by_species(d))
  print(js)
  doc <- jsonlite::fromJSON(as.character(js))
  gold <- jsonlite::fromJSON("data/p1.json")
  gap <- max(abs(unlist(doc) - unlist(gold)))
  cat("largest gap to golden/p1.json:", format(gap), "\n")
  msg <- "contract: c-m1 profile JSON equals the golden: "
  h$verdict(msg, gap < 1e-9)
}

if (sys.nframe() == 0) run_scene()
