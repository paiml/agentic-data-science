# C-M3 video 5: the p3 tests are green on the real tree.
# Usage (from the repo root): source("this file")
library(agenticds)
res <- as.data.frame(testthat::test_file(
  "r/agenticds/tests/testthat/test-p3.R",
  reporter = "silent", stop_on_failure = FALSE
))
cat(sprintf(
  "%d passed, %d failed, %d errors\n",
  sum(res$passed), sum(res$failed), sum(res$error)
))
d <- na_policy(read_penguins("datasets/penguins/penguins.csv"))
s <- read_split("datasets/fixtures/split.csv")
fit <- fit_species_clf(d[s == "train", ])
pred <- predict_species_clf(fit, d[s == "test", ])
truth <- factor(d$species[s == "test"], levels = levels(pred))
cat(sprintf("accuracy %.4f\n", accuracy(truth, pred)))
stopifnot(
  sum(res$failed) + sum(res$error) == 0,
  sum(res$passed) > 0
)
verdict("contract: ads-r-p3 tests green OK")
