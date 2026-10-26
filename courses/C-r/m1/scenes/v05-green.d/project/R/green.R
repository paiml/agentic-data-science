# v05 green: the p1 tests pass, no failures
h <- new.env()
sys.source("R/helpers.R", envir = h)

run_scene <- function() {
  stopifnot(h$check_sums("data"))
  res <- h$p1_suite()
  cat("passed:", sum(res), " failed:", sum(!res), "\n")
  print(names(res))
  h$verdict("contract: c-m1 p1 tests green: ", all(res))
}

if (sys.nframe() == 0) run_scene()
