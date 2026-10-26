# v01: the ticket's oracle is the golden file
h <- new.env()
sys.source("R/helpers.R", envir = h)

run_scene <- function() {
  g <- jsonlite::fromJSON("data/p2.json")
  print(names(g))
  print(round(unlist(g$ols), 2))
  want <- c("ols", "species_model", "metrics", "cv_rmse")
  ok <- all(want %in% names(g))
  h$verdict("all four oracle entries present", ok)
}

if (sys.nframe() == 0) run_scene()
