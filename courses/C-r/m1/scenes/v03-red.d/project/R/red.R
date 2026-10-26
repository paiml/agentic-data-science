# v03 red: a no-op NA policy, the tests go red
h <- new.env()
sys.source("R/helpers.R", envir = h)

run_scene <- function() {
  stopifnot(h$check_sums("data"))
  noop <- function(df) dplyr::filter(df, TRUE)
  grn <- h$p1_suite()
  red <- h$p1_suite(policy = noop)
  cat("real  passed", sum(grn), "failed", sum(!grn), "\n")
  cat("no-op passed", sum(red), "failed", sum(!red), "\n")
  print(names(red)[!red])
  ok <- all(grn) && any(!red)
  h$verdict("contract: c-m1 no-op NA policy caught: ", ok)
}

if (sys.nframe() == 0) run_scene()
