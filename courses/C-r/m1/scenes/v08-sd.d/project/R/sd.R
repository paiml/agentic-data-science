# v08 sd: population sd in a scratch copy, tests catch it
h <- new.env()
sys.source("R/helpers.R", envir = h)

run_scene <- function() {
  stopifnot(h$check_sums("data"))
  pop <- \(x) sqrt(mean((x - mean(x))^2))
  g <- h$p1_suite()
  r <- h$p1_suite(sd_fn = pop)
  cat("sample sd passed", sum(g), "failed", sum(!g), "\n")
  cat("pop sd    passed", sum(r), "failed", sum(!r), "\n")
  print(names(r)[!r])
  ok <- all(g) && any(!r)
  h$verdict("contract: c-m1 population sd caught: ", ok)
}

if (sys.nframe() == 0) run_scene()
