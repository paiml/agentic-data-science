# v10: both P2 examples run their own contract
h <- new.env()
sys.source("R/helpers.R", envir = h)

run_scene <- function() {
  ex <- c("c-m2-p2-ols", "c-m2-p2-cv")
  out <- unlist(lapply(ex, function(e) {
    run <- file.path("examples", e, "run.R")
    utils::capture.output(source(run, local = new.env()))
  }))
  hits <- out[startsWith(out, "contract: ")]
  writeLines(hits)
  ok <- length(hits) == 2
  h$verdict("two contracts, both OK", ok)
}

if (sys.nframe() == 0 && !run_scene()) quit(status = 1)
