# C-M4 video 7: the data, golden and report checks, one by one.
# Usage (from the repo root): source("<this file>")
wine <- "datasets/wine-quality"
golden <- file.path("datasets", "golden")
golden <- file.path(golden, c("p4.json", "p4-artifact.ttl"))
sums <- strsplit(readLines(file.path(wine, "SHA256SUMS")), " ")
match_sum <- function(s) {
  f <- file.path(wine, s[length(s)])
  have <- system2("sha256sum", f, stdout = TRUE)
  substr(have, 1, 64) == s[1]
}
w <- sprintf("%s/winequality-%s.csv", wine, c("red", "white"))
res <- agenticds::pipeline_wine(w[1], w[2])
agenticds::report_ttl(res, out <- tempfile(fileext = ".ttl"))
g <- jsonlite::fromJSON(golden[1])
k <- c("rmse", "r2")
gates <- c(
  datasets = all(vapply(sums, match_sum, logical(1))),
  golden = isTRUE(all.equal(unlist(g[k]), unlist(res[k]), 1e-6)),
  report = identical(readLines(out), readLines(golden[2]))
)
print(gates)
stopifnot(all(gates))
agenticds::verdict("contract: ads-r-p4 all three gates pass OK")
