# the gate, run locally: tests, parse, exports
res <- as.data.frame(testthat::test_dir("r/agenticds/tests/testthat",
  filter = "p[1-4]", package = "agenticds", load_package = "source",
  reporter = "silent", stop_on_failure = FALSE))
tests <- sum(res$failed) + sum(res$error) == 0
files <- list.files("r/agenticds/R", full.names = TRUE)
parse_ok <- all(sapply(files, function(f) length(parse(f)) > 0))
src <- unlist(lapply(files, readLines))
n_tag <- sum(grepl("^#' @export", src))
n_ns <- sum(grepl("^export\\(", readLines("r/agenticds/NAMESPACE")))
c(tests = tests, parse = parse_ok, exports = n_tag == n_ns)
ok <- tests && parse_ok && n_tag == n_ns
cat(cli::col_green(cli::style_bold(ok)), "\n")
