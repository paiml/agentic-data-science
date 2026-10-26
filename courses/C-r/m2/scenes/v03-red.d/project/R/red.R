# v03: an oracle must be able to fail: plant a bug
h <- new.env()
sys.source("R/helpers.R", envir = h)

run_scene <- function() {
  d <- h$load_clean("data/penguins.csv")
  b <- h$ols_closed_form(
    d$flipper_length_mm, d$body_mass_g
  )
  g <- jsonlite::fromJSON("data/p2.json")
  broken <- b[["slope"]] + 1
  r <- all.equal(g$ols$slope, broken, tolerance = 1e-9)
  cat("golden slope:", round(g$ols$slope, 2), "\n")
  cat("broken slope:", round(broken, 2), "\n")
  cat(cli::col_red(r), "\n")
  h$verdict("oracle caught the planted bug", !isTRUE(r))
}

if (sys.nframe() == 0) run_scene()
