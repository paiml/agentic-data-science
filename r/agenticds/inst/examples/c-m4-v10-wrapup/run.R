# C-M4 video 10: run both P4 examples, read back their contracts.
# Run from the repo root: source("<this file>")
library(agenticds)
ex <- c("c-m4-p4-pipeline", "c-m4-p4-bench")
out <- lapply(ex, function(e) {
  utils::capture.output(source(
    file.path("r", "agenticds", "inst", "examples", e, "run.R"),
    local = TRUE
  ))
})
lines <- grep("^contract: ads-r-p4", unlist(out), value = TRUE)
writeLines(lines)
stopifnot(length(lines) == 2L, all(endsWith(lines, "OK")))
verdict("contract: ads-r-p4 both example contracts hold OK")

# The lesson figure: $ADS_OUT/plot.svg from the lesson dataset (no-op when ADS_OUT is unset).
invisible(agenticds::figure_demo("c-m4-v10-wrapup"))
