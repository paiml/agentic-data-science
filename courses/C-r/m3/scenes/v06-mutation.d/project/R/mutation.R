# v06 mutation: are the checks strong enough? mutate live
h <- source("R/helpers.R")$value

run_scene <- function() {
  d <- h$load_clean("data/penguins.csv")
  cen <- h$read_centroids("data/centroids.csv")
  g <- jsonlite::fromJSON("data/p3.json")$kmeans$objective
  src <- h$fn_source(h$kmeans_fixed)
  m1 <- h$mutant(src, ")^2)", "))")
  m2 <- h$mutant(src, "= spread", "= 2 * spread")
  dies <- function(m) abs(m(d, cen)$objective - g) > 1e-6
  dead <- c(no_square = dies(m1), double_scale = dies(m2))
  print(dead)
  h$verdict("contract: c-m3 both mutants die: ", all(dead))
}

if (sys.nframe() == 0) run_scene()
