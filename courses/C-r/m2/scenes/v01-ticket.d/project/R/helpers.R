# Plumbing for the scene: not shown on camera.

verdict <- function(msg, ok) {
  txt <- cli::style_bold(paste0(msg, ": ", ok))
  col <- if (ok) cli::col_green else cli::col_red
  cat(col(txt), "\n")
  invisible(ok)
}
