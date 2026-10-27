# C-M2 video 10: what the gate proved; both P2 examples.
# Usage (from the repo root): source("<this file>")
library(agenticds)
ex <- c("c-m2-p2-ols", "c-m2-p2-cv")
out <- lapply(ex, function(e) {
  utils::capture.output(source(
    file.path("r/agenticds/inst/examples", e, "run.R"),
    local = new.env()
  ))
})
contracts <- vapply(
  out, function(o) grep("^contract:", o, value = TRUE), ""
)
cat("example 1:", contracts[1], "\n")
cat("example 2:", contracts[2], "\n")
stopifnot(all(grepl("^contract: ads-r-p2 .* OK$", contracts)))
verdict("contract: ads-r-p2 both examples hold their contract OK")
