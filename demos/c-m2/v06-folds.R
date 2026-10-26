# C-M2 video 6 (native R): fixed folds assigned by row index give the same CV twice.
source("demos/native-lib.R")
src <- c(
  "d <- na_policy(read_penguins(\"datasets/penguins/penguins.csv\"))",
  "f <- read_folds(\"datasets/fixtures/folds.csv\")",
  "table(f)",
  "run1 <- c(cv_rmse(d, f, FALSE), cv_rmse(d, f, TRUE))",
  "run2 <- c(cv_rmse(d, f, FALSE), cv_rmse(d, f, TRUE))",
  "identical(run1, run2) && identical(as.integer(f[1:10]), rep(1:5, 2))")
d <- na_policy(read_penguins("datasets/penguins/penguins.csv"))
f <- read_folds("datasets/fixtures/folds.csv")
run1 <- c(cv_rmse(d, f, FALSE), cv_rmse(d, f, TRUE))
run2 <- c(cv_rmse(d, f, FALSE), cv_rmse(d, f, TRUE))
nat_show("fixed folds by row index: the same CV twice", src)
nat_row("folds 1..5", paste(as.integer(table(f)), collapse = "  "))
nat_row("run 1", sprintf("line %.1f   species %.1f", run1[1], run1[2]))
nat_row("run 2", sprintf("line %.1f   species %.1f", run2[1], run2[2]))
nat_verdict(src[6], identical(run1, run2) && identical(as.integer(f[1:10]), rep(1:5, 2)),
  "contract: c-m2 fixed folds repeatable OK")
