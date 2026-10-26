# v07 gates: the style gates run locally, then the p1 tests
h <- new.env()
sys.source("R/helpers.R", envir = h)

run_scene <- function() {
  stopifnot(h$check_sums("data"))
  files <- list.files("R", full.names = TRUE)
  src <- unlist(lapply(files, readLines))
  wide <- sum(nchar(src) > 68)
  tabs <- sum(grepl("\t", src, fixed = TRUE))
  scene <- length(readLines("R/gates.R"))
  cat("files", length(files), " lines", length(src), "\n")
  cat("over 68 cols:", wide, " tabs:", tabs, "\n")
  cat("scene file lines:", scene, "\n")
  res <- h$p1_suite()
  cat("p1 tests passed", sum(res), "of", length(res), "\n")
  ok <- wide == 0 && tabs == 0 && scene <= 25 && all(res)
  h$verdict("contract: c-m1 gates green: ", ok)
}

if (sys.nframe() == 0) run_scene()
