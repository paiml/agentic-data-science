# C-M1 video 8: swap sample sd for population sd; see it caught.
# Run from the repo root: source("<this file>")
library(agenticds)
old <- deparse(summarise_by_species)
src <- paste(old, collapse = "\n")
pop_sd <- "function(x) sqrt(mean((x - mean(x))^2))"
src <- sub("stats::sd", pop_sd, src, fixed = TRUE)
broken <- eval(parse(text = src))
environment(broken) <- environment(summarise_by_species)
cat("- sd = stats::sd\n+ sd =", pop_sd, "\n")
env <- new.env(parent = asNamespace("agenticds"))
env$summarise_by_species <- broken
tdir <- "r/agenticds/tests/testthat"
res <- as.data.frame(testthat::test_file(
  file.path(tdir, "test-p1.R"), reporter = "silent",
  stop_on_failure = FALSE, env = env
))
cat("passed", sum(res$passed), "failed", sum(res$failed), "\n")
cat(paste("FAILED:", res$test[res$failed > 0]), sep = "\n")
stopifnot(!identical(deparse(broken), old))
stopifnot(sum(res$failed) > 0, !any(res$error))
verdict("contract: ads-r-p1 a population sd is caught OK")
