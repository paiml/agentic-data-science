# C-M1 video 3: red first. Break na_policy in a copy; see it caught.
# Run from the repo root: source("<this file>")
library(agenticds)
old <- deparse(na_policy)
src <- paste(old, collapse = "\n")
src <- sub("!is.na(.x)", "TRUE", src, fixed = TRUE)
broken <- eval(parse(text = src))
environment(broken) <- environment(na_policy)
new <- deparse(broken)
cat("- ", old[old != new], "\n+ ", new[new != old], "\n", sep = "")
env <- new.env(parent = asNamespace("agenticds"))
env$na_policy <- broken
tdir <- "r/agenticds/tests/testthat"
res <- as.data.frame(testthat::test_file(
  file.path(tdir, "test-p1.R"), reporter = "silent",
  stop_on_failure = FALSE, env = env
))
cat("passed", sum(res$passed), "failed", sum(res$failed), "\n")
cat(paste("FAILED:", res$test[res$failed > 0]), sep = "\n")
stopifnot(length(new) == length(old), !identical(new, old))
stopifnot(sum(res$failed) > 0, !any(res$error))
verdict("contract: ads-r-p1 a no-op NA policy is caught OK")
