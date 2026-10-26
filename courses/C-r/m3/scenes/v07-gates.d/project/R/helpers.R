# helpers: plumbing only, nothing here is shown on camera
verdict <- function(msg, ok) {
  paint <- if (ok) cli::col_green else cli::col_red
  cat(paint(cli::style_bold(paste0(msg, ok))), "\n")
  invisible(ok)
}

#' @export
tests_pass <- function(dir) {
  r <- as.data.frame(testthat::test_dir(
    dir,
    reporter = "silent", stop_on_failure = FALSE
  ))
  sum(r$failed) == 0 && !any(r$error) && sum(r$passed) > 0
}

#' @export
parses_ok <- function(files) {
  all(vapply(files, function(f) {
    !inherits(try(parse(f), silent = TRUE), "try-error")
  }, logical(1)))
}

#' @export
exports_match <- function(files, namespace) {
  lines <- unlist(lapply(files, readLines))
  at <- which(lines == "#' @export")
  tagged <- sub(" <- .*", "", lines[at + 1])
  ns <- grep("^export\\(", readLines(namespace), value = TRUE)
  setequal(tagged, sub("^export\\((.*)\\)$", "\\1", ns))
}

list(
  verdict = verdict,
  tests_pass = tests_pass,
  parses_ok = parses_ok,
  exports_match = exports_match
)
