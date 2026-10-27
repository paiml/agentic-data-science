# C-M3 video 7: lint, style and tests-per-export on the P3 code.
library(agenticds)
code <- "r/agenticds/R/p3.R"
test <- "r/agenticds/tests/testthat/test-p3.R"
files <- c(code, test)
lints <- sum(vapply(files, function(f) length(lintr::lint(f)), 1L))
cat(sprintf("lintr: %d lints\n", lints))
invisible(utils::capture.output(
  sty <- styler::style_file(files, dry = "on")
))
cat(sprintf("styler: %d files would change\n", sum(sty$changed)))
lines <- readLines(code)
fns <- sub(" <-.*", "", lines[grep("^#' @export", lines) + 1])
tested <- vapply(fns, function(f) {
  any(grepl(paste0("\\b", f, "\\("), readLines(test)))
}, NA)
cat(sprintf("exports: %d, without a test: %d\n",
            length(fns), sum(!tested)))
stopifnot(lints == 0, sum(sty$changed) == 0, all(tested))
verdict("contract: ads-r-p3 lint, style, tests per export OK")
