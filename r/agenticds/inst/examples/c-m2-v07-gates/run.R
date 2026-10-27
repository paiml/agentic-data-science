# C-M2 video 7: the R gates, run locally on the P1 and P2 code.
# Usage (from the repo root): source("<this file>")
library(agenticds)
library(testthat)
pkg <- "r/agenticds"
src <- file.path(pkg, "R", c("p1.R", "p2.R"))
tst <- file.path(
  pkg, "tests", "testthat", c("test-p1.R", "test-p2.R")
)
invisible(utils::capture.output(
  cov <- withr::with_envvar(
    c(ADS_ROOT = getwd()),
    covr::file_coverage(src, tst)
  )
))
pct <- covr::percent_coverage(cov)
lints <- sum(vapply(src, function(f) length(lintr::lint(f)), 1L))
invisible(utils::capture.output(
  sty <- styler::style_file(src, dry = "on")
))
changed <- sum(sty$changed)
cat(sprintf("covr: %g%% line coverage\n", pct))
cat(sprintf("lintr: %d lints\n", lints))
cat(sprintf("styler: %d files would change\n", changed))
stopifnot(pct == 100, lints == 0, changed == 0)
verdict("contract: ads-r-p2 coverage, lint, style gates green OK")
