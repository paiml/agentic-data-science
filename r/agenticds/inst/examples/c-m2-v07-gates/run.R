# C-M2 video 7: the R gates, run locally on the P1 and P2 code.
# Usage (from the repo root): source("<this file>")
pkg <- "r/agenticds"
src <- file.path(pkg, "R", c("p1.R", "p2.R"))
tst <- sub("R/p", "tests/testthat/test-p", src)
cover <- function() {
  withr::with_envvar(
    c(ADS_ROOT = getwd()),
    withr::with_package("testthat", covr::file_coverage(src, tst))
  )
}
invisible(utils::capture.output(
  cov <- withr::with_preserve_seed(cover())
))
pct <- covr::percent_coverage(cov)
lints <- sum(vapply(src, function(f) length(lintr::lint(f)), 1L))
invisible(utils::capture.output(
  sty <- styler::style_file(src, dry = "on")
))
cat(sprintf("covr: %g%% line coverage\n", pct))
cat(sprintf("lintr: %d lints\n", lints))
cat(sprintf("styler: %d files would change\n", sum(sty$changed)))
stopifnot(pct == 100, lints == 0, sum(sty$changed) == 0)
agenticds::verdict(
  "contract: ads-r-p2 coverage, lint, style gates green OK"
)
