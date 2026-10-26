# c-m4 v08: dplyr vs data.table, equal results
h <- new.env()
sys.source("R/helpers.R", h)
library(agenticds)

run_scene <- function() {
  w <- read_wine(h$wine("red"), h$wine("white"))
  a <- aggregate_dplyr(w)
  b <- aggregate_data_table(w)
  print(a)
  print(b)
  cat("timings (seconds, not asserted):\n")
  print(bench_wine(w, reps = 5L))
  h$verdict(isTRUE(all.equal(a, b)), "dplyr == data.table")
}

if (sys.nframe() == 0) run_scene()
