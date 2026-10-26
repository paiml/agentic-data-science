# C-M3 video 2 (native R): the tree on the fixed split reproduces the golden confusion matrix.
source("demos/native-lib.R")
src <- c(
  "d <- na_policy(read_penguins(\"datasets/penguins/penguins.csv\"))",
  "g <- jsonlite::fromJSON(\"datasets/golden/p3.json\")",
  "s <- read_split(\"datasets/fixtures/split.csv\")",
  "fit <- fit_species_clf(d[s == \"train\", ])",
  "pred <- predict_species_clf(fit, d[s == \"test\", ])",
  "truth <- factor(d$species[s == \"test\"], levels = levels(pred))",
  "isTRUE(all.equal(accuracy(truth, pred), g$accuracy))")
d <- na_policy(read_penguins("datasets/penguins/penguins.csv"))
g <- jsonlite::fromJSON("datasets/golden/p3.json")
s <- read_split("datasets/fixtures/split.csv")
fit <- fit_species_clf(d[s == "train", ])
pred <- predict_species_clf(fit, d[s == "test", ])
truth <- factor(d$species[s == "test"], levels = levels(pred))
nat_show("the tree on the fixed split, against the golden matrix", src)
nat_row("accuracy", sprintf("%.4f", accuracy(truth, pred)))
nat_row("errors", sprintf("%d of %d", sum(truth != pred), length(truth)))
nat_row("golden accuracy", sprintf("%.4f", g$accuracy))
nat_verdict(src[7], isTRUE(all.equal(accuracy(truth, pred), g$accuracy)),
  "contract: c-m3 tree accuracy 0.9765, 2 errors in 85 OK")
