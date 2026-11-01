# C-M4 video 8: two engines, one answer; timings are not checked.
# Run from the repo root: source("<this file>")
library(agenticds)
dir <- file.path("datasets", "wine-quality")
w <- read_wine(
  file.path(dir, "winequality-red.csv"),
  file.path(dir, "winequality-white.csv")
)
a <- aggregate_dplyr(w)
b <- aggregate_data_table(w)
print(a)
print(b)
cat("same answer; timings vary run to run, never checked:\n")
print(bench_wine(w, reps = 5L))
same <- all.equal(a$mean_quality, b$mean_quality, tolerance = 1e-12)
stopifnot(
  identical(a$color, b$color), identical(a$n, b$n), isTRUE(same)
)
verdict("contract: ads-r-p4 dplyr == data.table OK")
