# helpers: plumbing only, nothing here is shown on camera
feats <- c(
  "bill_length_mm", "bill_depth_mm",
  "flipper_length_mm", "body_mass_g"
)

verdict <- function(msg, ok) {
  paint <- if (ok) cli::col_green else cli::col_red
  cat(paint(cli::style_bold(paste0(msg, ok))), "\n")
  invisible(ok)
}

load_clean <- function(path) {
  d <- readr::read_csv(path, show_col_types = FALSE)
  tidyr::drop_na(d, tidyr::all_of(feats))
}

list(
  feats = feats,
  verdict = verdict,
  load_clean = load_clean
)
