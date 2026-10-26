# C-M3 video 5 (native R): the p3 tests are green on the real tree.
source("demos/native-lib.R")
src <- c(
  "res <- as.data.frame(testthat::test_dir(\"r/agenticds/tests/testthat\",",
  "  filter = \"p3\", package = \"agenticds\", load_package = \"source\",",
  "  reporter = \"silent\"))",
  "d <- na_policy(read_penguins(\"datasets/penguins/penguins.csv\"))",
  "s <- read_split(\"datasets/fixtures/split.csv\")",
  "pred <- predict_species_clf(fit_species_clf(d[s == \"train\", ]), d[s == \"test\", ])",
  "sum(res$failed) + sum(res$error) == 0 && sum(res$passed) > 0")
res <- as.data.frame(testthat::test_dir("r/agenticds/tests/testthat", filter = "p3", package = "agenticds",
  load_package = "source", reporter = "silent", stop_on_failure = FALSE))
d <- na_policy(read_penguins("datasets/penguins/penguins.csv"))
s <- read_split("datasets/fixtures/split.csv")
pred <- predict_species_clf(fit_species_clf(d[s == "train", ]), d[s == "test", ])
truth <- factor(d$species[s == "test"], levels = levels(pred))
nat_show("tests green on the real tree", src)
nat_row("tests", sprintf("%d passed   %d failed   %d errors", sum(res$passed), sum(res$failed), sum(res$error)))
nat_row("accuracy", sprintf("%.4f   (%d errors in %d)", accuracy(truth, pred), sum(truth != pred), length(truth)))
nat_verdict(src[7], sum(res$failed) + sum(res$error) == 0 && sum(res$passed) > 0,
  "contract: c-m3 tests green OK")
