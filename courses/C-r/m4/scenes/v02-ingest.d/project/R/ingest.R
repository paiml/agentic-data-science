# c-m4 v02: read_wine, red + white row counts
h <- new.env()
sys.source("R/helpers.R", h)
library(agenticds)

run_scene <- function() {
  w <- read_wine(h$wine("red"), h$wine("white"))
  print(dplyr::count(w, dplyr::pick("color")))
  g <- jsonlite::fromJSON("data/p4.json")
  n <- nrow(w)
  h$verdict(n == g$n_rows, sprintf("%d rows", n))
}

if (sys.nframe() == 0) run_scene()
