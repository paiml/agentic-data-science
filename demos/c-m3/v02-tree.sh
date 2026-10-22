#!/usr/bin/env bash
# shellcheck disable=SC2016
# C-M3 video 2: the tree on the fixed split
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
Rscript -e 'library(agenticds)
d <- na_policy(read_penguins("datasets/penguins/penguins.csv"))
g <- jsonlite::fromJSON("datasets/golden/p3.json")
s <- read_split("datasets/fixtures/split.csv")
fit <- fit_species_clf(d[s == "train", ])
pred <- predict_species_clf(fit, d[s == "test", ])
truth <- factor(d$species[s == "test"], levels = levels(pred))
print(confusion(truth, pred))
cat(sprintf("accuracy %.4f = %d/%d, errors %d\n", accuracy(truth, pred), sum(truth == pred), length(truth), sum(truth != pred)))
stopifnot(sum(truth != pred) == 2L, abs(accuracy(truth, pred) - g$accuracy) < 1e-12)
cat("contract: c-m3 tree accuracy 0.9765, 2 errors in 85 OK\n")'
