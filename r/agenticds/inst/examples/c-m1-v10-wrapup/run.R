# C-M1 video 10: wrap-up. Both P1 contracts, then the module's.
# Run from the repo root: source("<this file>")
library(agenticds)
ex <- file.path("r", "agenticds", "inst", "examples")
lines <- character()
for (name in c("c-m1-p1", "c-m1-p1-profile")) {
  out <- utils::capture.output(
    source(file.path(ex, name, "run.R"), local = new.env())
  )
  lines <- c(lines, grep("^contract:", out, value = TRUE))
}
cat(lines, sep = "\n")
stopifnot(
  length(lines) == 2L,
  all(grepl("^contract: ads-r-p1 .* OK$", lines))
)
verdict("contract: ads-r-p1 module 1 wrap-up OK")
