# c-m4 v07: the gates, checksums and artifact shape
h <- new.env()
sys.source("R/helpers.R", h)

run_scene <- function() {
  sums <- h$check_sums("data")
  cat("SHA256SUMS:", sums, "\n")
  ttl <- h$read_ttl("data/p4-artifact.ttl")
  shape <- h$shape_ok(ttl)
  print(shape)
  g <- jsonlite::fromJSON("data/p4.json")
  rmse <- h$has_num(ttl, g$rmse)
  h$verdict(sums && all(shape) && rmse, "gates green")
}

if (sys.nframe() == 0) run_scene()
