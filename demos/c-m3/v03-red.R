# C-M3 video 3 (native R): invert the accuracy test; the golden oracle goes red.
source("demos/native-lib.R")
src <- c(
  "d <- na_policy(read_penguins(\"datasets/penguins/penguins.csv\"))",
  "g <- jsonlite::fromJSON(\"datasets/golden/p3.json\")",
  "s <- read_split(\"datasets/fixtures/split.csv\")",
  "pred <- predict_species_clf(fit_species_clf(d[s == \"train\", ]), d[s == \"test\", ])",
  "truth <- factor(d$species[s == \"test\"], levels = levels(pred))",
  "broken <- mean(truth != pred)             # the planted bug: == inverted",
  "r <- all.equal(broken, g$accuracy, tolerance = 1e-9)",
  "!isTRUE(r)")
d <- na_policy(read_penguins("datasets/penguins/penguins.csv"))
g <- jsonlite::fromJSON("datasets/golden/p3.json")
s <- read_split("datasets/fixtures/split.csv")
pred <- predict_species_clf(fit_species_clf(d[s == "train", ]), d[s == "test", ])
truth <- factor(d$species[s == "test"], levels = levels(pred))
broken <- mean(truth != pred)
r <- all.equal(broken, g$accuracy, tolerance = 1e-9)
nat_show("invert the accuracy test: the golden oracle must go red", src)
nat_row("golden accuracy", sprintf("%.4f", g$accuracy))
cat(cli::col_cyan(sprintf("%-16s", "broken accuracy")), cli::col_red(sprintf("%.4f   %s", broken, r)), "\n", sep = "")
nat_verdict(src[8], !isTRUE(r), "contract: c-m3 inverted accuracy is caught OK")
