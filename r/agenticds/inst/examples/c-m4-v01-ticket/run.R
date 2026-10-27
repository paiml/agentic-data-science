# C-M4 video 1: the ticket's oracle. Run: source("<this file>")
library(agenticds)
dir <- file.path("datasets", "wine-quality")
sums <- readLines(file.path(dir, "SHA256SUMS"))
for (s in strsplit(sums, " ")) {
  f <- file.path(dir, s[length(s)])
  have <- substr(system2("sha256sum", f, stdout = TRUE), 1, 64)
  cat(s[length(s)], ":", if (have == s[1]) "OK" else "FAILED", "\n")
  stopifnot(have == s[1])
}
g <- jsonlite::fromJSON("datasets/golden/p4.json")
p <- file.path(dir, paste0("winequality-", c("red", "white")))
p <- paste0(p, ".csv")
df <- read_wine(p[1], p[2])
cat(sprintf(
  "golden: rows %d (train %d, test %d)  rmse %.4f  r2 %.4f\n",
  g$n_rows, g$n_train, g$n_test, g$rmse, g$r2
))
cat("data:   rows", nrow(df), " red/white", table(df$color), "\n")
stopifnot(
  g$n_rows == nrow(df), g$n_train + g$n_test == g$n_rows,
  g$n_test == nrow(df) %/% 5L
)
verdict("contract: ads-r-p4 ticket oracle matches data 6497 OK")
