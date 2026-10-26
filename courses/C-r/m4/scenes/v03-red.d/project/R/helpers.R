wine <- function(color) {
  sprintf("data/winequality-%s.csv", color)
}

verdict <- function(ok, msg) {
  style <- if (ok) cli::col_green else cli::col_red
  line <- paste0("contract: c-m4 ", msg, ": ", ok)
  cat(style(cli::style_bold(line)), "\n")
  invisible(ok)
}
