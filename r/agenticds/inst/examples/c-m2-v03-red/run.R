# C-M2 video 3: plant a slope bug in a copy; the tests go red.
# Usage (from the repo root): source("<this file>")
library(agenticds)
old <- deparse(ols_closed_form)
src <- paste(old, collapse = "\n")
src <- sub("slope = b[[2]]", "slope = b[[1]]", src, fixed = TRUE)
broken <- eval(parse(text = src))
environment(broken) <- environment(ols_closed_form)
new <- deparse(broken)
cat("- ", old[old != new], "\n+ ", new[new != old], "\n", sep = "")
env <- new.env(parent = asNamespace("agenticds"))
env$ols_closed_form <- broken
tdir <- "r/agenticds/tests/testthat"
res <- as.data.frame(testthat::test_file(
  file.path(tdir, "test-p2.R"), reporter = "silent",
  stop_on_failure = FALSE, env = env
))
cat("passed", sum(res$passed), "failed", sum(res$failed), "\n")
cat(paste("FAILED:", res$test[res$failed > 0]), sep = "\n")
stopifnot(length(new) == length(old), !identical(new, old))
stopifnot(sum(res$failed) > 0, !any(res$error))
verdict("contract: ads-r-p2 a wrong slope is caught OK")
