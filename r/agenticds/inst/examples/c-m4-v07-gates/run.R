# C-M4 video 7: each gate either passes or blocks the merge.
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
res <- pipeline_wine(sprintf(f, "red"), sprintf(f, "white"))
report_ttl(res, out <- tempfile(fileext = ".ttl"))
g <- jsonlite::fromJSON(file.path(gold, "p4.json"))
k <- c("rmse", "r2")
gates <- c(
  datasets = all(vapply(sums, match_sum, logical(1))),
  golden = isTRUE(all.equal(unlist(g[k]), unlist(res[k]), 1e-6)),
  report = identical(readLines(out),
                     readLines(file.path(gold, "p4-artifact.ttl")))
)
print(gates)
stopifnot(all(gates))
verdict("contract: ads-r-p4 all three gates pass OK")
