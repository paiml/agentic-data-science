# C-M3 video 3: invert the accuracy test; the tests go red.
# Usage (from the repo root): source("this file")
library(agenticds)
old <- deparse(accuracy)
src <- paste(old, collapse = "\n")
src <- sub("truth == pred", "truth != pred", src, fixed = TRUE)
broken <- eval(parse(text = src))
environment(broken) <- environment(accuracy)
new <- deparse(broken)
cat("- ", old[old != new], "\n+ ", new[new != old], "\n", sep = "")
env <- new.env(parent = asNamespace("agenticds"))
env$accuracy <- broken
tdir <- "r/agenticds/tests/testthat"
res <- as.data.frame(testthat::test_file(
  file.path(tdir, "test-p3.R"), reporter = "silent",
  stop_on_failure = FALSE, env = env
))
cat("passed", sum(res$passed), "failed", sum(res$failed), "\n")
cat(paste("FAILED:", res$test[res$failed > 0]), sep = "\n")
stopifnot(length(new) == length(old), !identical(new, old))
stopifnot(sum(res$failed) > 0, !any(res$error))
verdict("contract: ads-r-p3 inverted accuracy is caught OK")
