# C-M3 video 7: the quality gates, run locally on the P3 code.
# Usage (from the repo root): source("this file")
library(agenticds)
code <- "r/agenticds/R/p3.R"
test <- "r/agenticds/tests/testthat/test-p3.R"
lin <- lintr::linters_with_defaults(
  line_length_linter = lintr::line_length_linter(68)
)
lints <- length(lintr::lint(code, linters = lin))
cat(sprintf("lintr: %d lints\n", lints))
invisible(utils::capture.output(
  sty <- styler::style_file(c(code, test), dry = "on")
))
cat(sprintf("styler: %d files would change\n", sum(sty$changed)))
lines <- readLines(code)
fns <- sub(" <-.*", "", lines[grep("^#' @export", lines) + 1])
tested <- vapply(fns, function(f) {
  any(grepl(paste0(f, "("), readLines(test), fixed = TRUE))
}, NA)
cat(sprintf("exports: %d, without a test: %d\n",
            length(fns), sum(!tested)))
stopifnot(lints == 0, sum(sty$changed) == 0, all(tested))
verdict("contract: ads-r-p3 gates green OK")
