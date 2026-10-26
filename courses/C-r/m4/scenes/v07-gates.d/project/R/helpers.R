wine <- function(color) {
  sprintf("data/winequality-%s.csv", color)
}

verdict <- function(ok, msg) {
  style <- if (ok) cli::col_green else cli::col_red
  line <- paste0("contract: c-m4 ", msg, ": ", ok)
  cat(style(cli::style_bold(line)), "\n")
  invisible(ok)
}

check_sums <- function(dir) {
  old <- setwd(dir)
  on.exit(setwd(old))
  args <- c("-c", "--quiet", "SHA256SUMS")
  system2("sha256sum", args) == 0
}

shape_ok <- function(ttl) {
  need <- c(
    "a ads:Artifact", "ads:schemaVersion", "ads:generatedBy"
  )
  vapply(need, grepl, logical(1), x = ttl, fixed = TRUE)
}

read_ttl <- function(path) {
  paste(readLines(path), collapse = "\n")
}

has_num <- function(ttl, x) {
  grepl(sprintf("%.10f", x), ttl, fixed = TRUE)
}
