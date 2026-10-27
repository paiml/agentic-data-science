# C-M3 video 2: the tree on the fixed split vs the golden matrix.
# Usage (from the repo root): source("this file")
library(agenticds)
d <- na_policy(read_penguins("datasets/penguins/penguins.csv"))
g <- jsonlite::fromJSON("datasets/golden/p3.json")
s <- read_split("datasets/fixtures/split.csv")
fit <- fit_species_clf(d[s == "train", ])
pred <- predict_species_clf(fit, d[s == "test", ])
truth <- factor(d$species[s == "test"], levels = levels(pred))
cm <- confusion(truth, pred)
print(cm)
acc <- accuracy(truth, pred)
cat(sprintf("accuracy %.4f\n", acc))
cat(sprintf("errors %d of %d\n", sum(truth != pred), length(truth)))
stopifnot(
  isTRUE(all.equal(acc, g$accuracy, tolerance = 1e-9)),
  all(unclass(cm) == g$confusion)
)
verdict("contract: ads-r-p3 tree 0.9765, 2 errors in 85 OK")
