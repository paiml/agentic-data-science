# v07 gates: tests, parse and exports, run locally
h <- source("R/helpers.R")$value

run_scene <- function() {
  files <- list.files("R", "[.]R$", full.names = TRUE)
  checks <- c(
    tests = h$tests_pass("tests/checks"),
    parse = h$parses_ok(files),
    exports = h$exports_match(files, "NAMESPACE")
  )
  print(checks)
  h$verdict("contract: c-m3 gates green: ", all(checks))
}

if (sys.nframe() == 0) run_scene()
