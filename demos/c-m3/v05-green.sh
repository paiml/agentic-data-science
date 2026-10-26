#!/usr/bin/env bash
# shellcheck disable=SC2016
# C-M3 video 5: tests green, confusion matrix
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
Rscript -e 'library(agenticds)
d <- na_policy(read_penguins("datasets/penguins/penguins.csv"))
g <- jsonlite::fromJSON("datasets/golden/p3.json")
res <- as.data.frame(testthat::test_dir("r/agenticds/tests/testthat", filter = "p3", package = "agenticds", load_package = "installed", reporter = "silent", stop_on_failure = FALSE))
cat("expectations passed:", sum(res$passed), " failed:", sum(res$failed), "\n")
s <- read_split("datasets/fixtures/split.csv")
fit <- fit_species_clf(d[s == "train", ])
pred <- predict_species_clf(fit, d[s == "test", ])
print(confusion(factor(d$species[s == "test"], levels = levels(pred)), pred))
stopifnot(sum(res$failed) == 0, sum(res$error) == 0, !any(res$skipped), sum(res$passed) > 0)
cat("contract: c-m3 tests green OK\n")'
