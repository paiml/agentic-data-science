# v02: closed-form OLS, scored against the golden R squared
h <- new.env()
sys.source("R/helpers.R", envir = h)

run_scene <- function() {
  d <- h$load_clean("data/penguins.csv")
  fit <- h$fit_line(d)
  m <- h$regression_metrics(d$body_mass_g, fit$fitted)
  g <- jsonlite::fromJSON("data/p2.json")
  cat(sprintf("slope %.2f g/mm\n", fit$b[["slope"]]))
  cat(sprintf("R squared %.3f\n", m$r2))
  want <- g$metrics$ols$r2
  ok <- isTRUE(all.equal(m$r2, want, tolerance = 1e-8))
  h$verdict("R squared matches golden", ok)
}

if (sys.nframe() == 0) run_scene()
