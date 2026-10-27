#' Print the contract line of an example, in green on a terminal.
#' @param text The contract line, ending in OK.
#' @param color Whether to wrap the line in ANSI colour codes.
#' @return The text, invisibly.
#' @export
verdict <- function(text, color = interactive()) {
  if (color) {
    cat("\033[38;5;83m", text, "\033[0m\n", sep = "")
  } else {
    cat(text, "\n", sep = "")
  }
  invisible(text)
}
