# Plumbing for the scene: not shown on camera.

model_cols <- c("flipper_length_mm", "body_mass_g")

load_clean <- function(path) {
  d <- readr::read_csv(path, show_col_types = FALSE)
  d <- tidyr::drop_na(d, tidyr::all_of(model_cols))
  dplyr::select(d, dplyr::all_of(c("species", model_cols)))
}

ols_closed_form <- function(x, y) {
  design <- cbind(1, x)
  b <- solve(crossprod(design), crossprod(design, y))
  c(intercept = b[[1]], slope = b[[2]])
}

verdict <- function(msg, ok) {
  txt <- cli::style_bold(paste0(msg, ": ", ok))
  col <- if (ok) cli::col_green else cli::col_red
  cat(col(txt), "\n")
  invisible(ok)
}
