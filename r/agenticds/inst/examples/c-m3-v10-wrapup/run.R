# C-M3 video 10: both P3 examples hold their contract.
# Usage (from the repo root): source("this file")
ex <- c("c-m3-p3-tree", "c-m3-p3-kmeans")
base <- file.path("r", "agenticds", "inst", "examples")
contract <- function(e) {
  out <- utils::capture.output(
    source(file.path(base, e, "run.R"), local = new.env())
  )
  grep("^contract:", out, value = TRUE)
}
lines <- vapply(ex, contract, "")
for (l in lines) {
  cat(l, "\n")
}
stopifnot(all(grepl("golden/p3.json OK$", lines)))
agenticds::verdict(
  "contract: ads-r-p3 tree and k-means both hold OK"
)
