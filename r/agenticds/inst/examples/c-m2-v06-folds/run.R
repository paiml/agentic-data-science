# C-M2 video 6: fixed folds give the same cross-validation twice.
# Usage (from the repo root): source("<this file>")
library(agenticds)
d <- na_policy(read_penguins("datasets/penguins/penguins.csv"))
f <- read_folds("datasets/fixtures/folds.csv")
print(table(f))
run1 <- c(cv_rmse(d, f, FALSE), cv_rmse(d, f, TRUE))
run2 <- c(cv_rmse(d, f, FALSE), cv_rmse(d, f, TRUE))
cat(sprintf("run 1: line %.1f, species %.1f\n", run1[1], run1[2]))
cat(sprintf("run 2: line %.1f, species %.1f\n", run2[1], run2[2]))
stopifnot(
  identical(run1, run2),
  identical(as.integer(f[1:10]), rep(1:5, 2)),
  identical(as.integer(table(f)), c(69L, 69L, 68L, 68L, 68L))
)
verdict("contract: ads-r-p2 fixed folds repeatable OK")
