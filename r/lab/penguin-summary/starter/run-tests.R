# Learner entry point: Rscript run-tests.R   (exit 0 = every check passed)
library(testthat)
Sys.setenv(LAB_DIR = normalizePath(getwd()))
source(file.path("R", "penguins.R"))
res <- as.data.frame(test_file(file.path("tests", "test-lab.R"), reporter = "summary", env = globalenv()))
cat(sprintf("Lab: penguin summary | tests=%d passed_expectations=%d failed=%d errors=%d\n",
            nrow(res), sum(res$passed), sum(res$failed), sum(res$error)))
if (nrow(res) == 0L) quit(status = 2)  # floor: zero tests is refused, not a pass
quit(status = if (any(res$failed > 0L | res$error)) 1L else 0L)
