# C-M1 video 3: red first. Break na_policy in a scratch copy of the
# package; the p1 tests must catch it.
# Run from the repo root: source("<this file>")
library(agenticds)
root <- normalizePath(".")
pkg <- file.path(root, "r", "agenticds")
scratch <- file.path(tempfile("red-"), "agenticds")
dir.create(dirname(scratch))
file.copy(pkg, dirname(scratch), recursive = TRUE)
p1 <- file.path(scratch, "R", "p1.R")
orig <- file.path(dirname(scratch), "p1.orig.R")
file.copy(file.path(pkg, "R", "p1.R"), orig)
src <- readLines(p1)
mutated <- sub("~ !is.na(.x)", "~ TRUE", src, fixed = TRUE)
writeLines(mutated, p1)
cat("changed in R/p1.R: the NA policy now keeps every row\n")
d <- suppressWarnings(
  system2("diff", c("-U0", orig, p1), stdout = TRUE)
)
cat(grep("^[-+][^-+]", d, value = TRUE), sep = "\n")

Sys.setenv(ADS_ROOT = root)
out <- tempfile(fileext = ".rds")
# a child R process, so the broken code never loads into this session
code <- sprintf(
  paste0(
    "r <- testthat::test_file(%s, reporter = 'silent',",
    " stop_on_failure = FALSE, load_package = 'source');",
    " saveRDS(as.data.frame(r), %s)"
  ),
  deparse(file.path(scratch, "tests", "testthat", "test-p1.R")),
  deparse(out)
)
system2(
  file.path(R.home("bin"), "Rscript"), c("-e", shQuote(code)),
  stdout = FALSE, stderr = FALSE
)
res <- readRDS(out)
failed <- sum(res$failed)
errored <- sum(res$error)
cat(sprintf(
  "Passed %d, Failed %d, Errored %d\n",
  sum(res$passed), failed, errored
))
bad <- res$test[res$failed > 0]
cat(paste("FAILED:", bad), sep = "\n")
expected <- c(
  "na_policy drops rows with NA in a numeric column only",
  "summarise_by_species gives n, mean and sample sd",
  "summary_json is a stable JSON document",
  "summary matches the committed golden within 1e-9"
)
ok <- failed > 0 && errored == 0 && all(bad %in% expected)
if (!ok) {
  verdict("contract: ads-r-p1 red run FAIL")
  stop("the red run was not caught as expected")
}
verdict("contract: ads-r-p1 a no-op NA policy is caught OK")
