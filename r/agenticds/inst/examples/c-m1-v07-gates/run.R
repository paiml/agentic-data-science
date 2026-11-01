# C-M1 video 7: coverage, lint and style, run locally.
# Run from the repo root: source("<this file>")
library(agenticds)
pkg <- file.path("r", "agenticds")
dir <- file.path(normalizePath(pkg), "tests", "testthat")
tests <- sprintf(paste0(
  "library(agenticds); testthat::test_dir('%s', ",
  "filter = 'p[1-4]|verdict', package = 'agenticds', ",
  "load_package = 'installed', reporter = 'silent', ",
  "stop_on_failure = TRUE)"
), dir)
cov <- covr::package_coverage(pkg, type = "none", code = tests)
pct <- covr::percent_coverage(cov)
cat("covr:", pct, "\n")
print(covr::zero_coverage(cov))
lints <- lintr::lint_package(pkg)
cat("lintr:", length(lints), "lints\n")
invisible(utils::capture.output(
  changed <- styler::style_pkg(pkg, dry = "on")$changed
))
cat("styler: changed", sum(changed), "files\n")
stopifnot(pct == 100, length(lints) == 0, !any(changed))
verdict("contract: ads-r-p1 coverage, lint, style green OK")
