# C-M4 video 7: each gate either passes or blocks the merge.
# Run from the repo root: source("<this file>")
library(agenticds)
wine <- file.path("datasets", "wine-quality")
gold <- file.path("datasets", "golden")
sums <- strsplit(readLines(file.path(wine, "SHA256SUMS")), " ")
match_sum <- function(s) {
  f <- file.path(wine, s[length(s)])
  have <- system2("sha256sum", f, stdout = TRUE)
  substr(have, 1, 64) == s[1]
}
f <- file.path(wine, "winequality-%s.csv")
out <- tempfile(fileext = ".ttl")
red <- sprintf(f, "red")
report_ttl(pipeline_wine(red, sprintf(f, "white")), out)
want <- readLines(file.path(gold, "p4-artifact.ttl"))
gates <- c(
  datasets = all(vapply(sums, match_sum, logical(1))),
  golden = file.size(file.path(gold, "p4.json")) > 0,
  report = identical(readLines(out), want)
)
print(gates)
stopifnot(all(gates))
verdict("contract: ads-r-p4 all three gates pass OK")
