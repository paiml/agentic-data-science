# Plumbing for the scene: not shown on camera.

model_cols <- c("flipper_length_mm", "body_mass_g")

load_clean <- function(path) {
  d <- readr::read_csv(path, show_col_types = FALSE)
  d <- tidyr::drop_na(d, tidyr::all_of(model_cols))
  dplyr::select(d, dplyr::all_of(c("species", model_cols)))
}

oracle <- function(d) {
  x <- cbind(1, d[[model_cols[1]]])
  colnames(x) <- c("(Intercept)", model_cols[1])
  drop(solve(crossprod(x), crossprod(x, d[[model_cols[2]]])))
}

theme_scene <- function() {
  ggplot2::theme_bw(base_size = 12) +
    ggplot2::theme(
      legend.position = "bottom",
      legend.title = ggplot2::element_blank()
    )
}

save_png <- function(p, file) {
  ggplot2::ggsave(file, p, width = 3.6, height = 5.4, dpi = 200)
  cli::cli_alert_success("Saved {.file {file}}")
}

verdict <- function(msg, ok) {
  txt <- cli::style_bold(paste0(msg, ": ", ok))
  col <- if (ok) cli::col_green else cli::col_red
  cat(col(txt), "\n")
  invisible(ok)
}
