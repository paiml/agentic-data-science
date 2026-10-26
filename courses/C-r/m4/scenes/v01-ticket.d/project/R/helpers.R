# Plumbing for the scene: paths, checksum gate, verdict colours.
wine <- function(color) {
  sprintf("data/winequality-%s.csv", color)
}

check_sums <- function(dir) {
  old <- setwd(dir)
  on.exit(setwd(old))
  args <- c("-c", "--quiet", "SHA256SUMS")
  system2("sha256sum", args) == 0
}

verdict <- function(ok, msg) {
  style <- if (ok) cli::col_green else cli::col_red
  line <- paste0("contract: c-m4 ", msg, ": ", ok)
  cat(style(cli::style_bold(line)), "\n")
  invisible(ok)
}
