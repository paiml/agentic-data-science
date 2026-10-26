# c-m4 v10: both P4 contracts run their own check
h <- new.env()
sys.source("R/helpers.R", h)

run_scene <- function() {
  ex <- c("c-m4-p4-pipeline", "c-m4-p4-bench")
  out <- unlist(lapply(ex, function(e) {
    run <- file.path("examples", e, "run.R")
    utils::capture.output(source(run, local = new.env()))
  }))
  hits <- grep("^contract:", out, value = TRUE)
  writeLines(hits)
  ok <- length(hits) == 2 && all(endsWith(hits, "OK"))
  h$verdict(ok, "two contracts, both OK")
}

if (sys.nframe() == 0) run_scene()
