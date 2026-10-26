# v08: the result, in-sample versus cross-validated RMSE
h <- new.env()
sys.source("R/helpers.R", envir = h)

run_scene <- function() {
  d <- h$load_clean("data/penguins.csv")
  f <- h$read_folds("data/folds.csv")
  line <- h$fit_line(d)$fitted
  inl <- h$regression_metrics(d$body_mass_g, line)$rmse
  cvl <- h$cv_rmse(d, f)
  cvs <- h$cv_rmse(d, f, species = TRUE)
  cat(sprintf("in-sample line    %.1f\n", inl))
  cat(sprintf("cross-val line    %.1f\n", cvl))
  cat(sprintf("cross-val species %.1f\n", cvs))
  cat(sprintf("species gain      %.1f g\n", cvl - cvs))
  ok <- cvl > inl && cvs < cvl
  h$verdict("CV above in-sample, species wins", ok)
}

if (sys.nframe() == 0) run_scene()
