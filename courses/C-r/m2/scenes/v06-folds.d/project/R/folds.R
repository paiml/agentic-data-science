# v06: fixed folds make cross-validation repeatable
h <- new.env()
sys.source("R/helpers.R", envir = h)

run_scene <- function() {
  d <- h$load_clean("data/penguins.csv")
  f <- h$read_folds("data/folds.csv")
  print(table(f))
  a <- h$cv_rmse(d, f)
  b <- h$cv_rmse(d, h$read_folds("data/folds.csv"))
  r1 <- h$cv_rmse(d, h$random_folds(nrow(d), 1))
  r2 <- h$cv_rmse(d, h$random_folds(nrow(d), 2))
  again <- h$cv_rmse(d, h$random_folds(nrow(d), 1))
  cat(sprintf("fixed folds: %.1f then %.1f\n", a, b))
  cat(sprintf("random seeds: %.1f then %.1f\n", r1, r2))
  ok <- identical(a, b) && identical(r1, again) &&
    r1 != r2 && identical(f[1:10], rep(1:5, 2))
  h$verdict("folds fixed, CV repeatable", ok)
}

if (sys.nframe() == 0 && !run_scene()) quit(status = 1)
