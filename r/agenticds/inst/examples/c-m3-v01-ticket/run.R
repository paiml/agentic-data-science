# C-M3 video 1: the ticket's oracle is the golden file p3.json.
# Usage (from the repo root): source("this file")
library(agenticds)
d <- na_policy(read_penguins("datasets/penguins/penguins.csv"))
g <- jsonlite::fromJSON("datasets/golden/p3.json")
print(g$confusion)
hit <- sum(diag(g$confusion))
n <- sum(g$confusion)
acc <- hit / n
cat(sprintf("golden accuracy %.4f = %d/%d\n", acc, hit, n))
sizes <- g$kmeans$cluster_sizes
cat("cluster sizes:", sizes, "\n")
cat("clean rows:", nrow(d), "\n")
stopifnot(
  abs(acc - g$accuracy) < 1e-12,
  nrow(d) == 342L,
  nrow(d) == sum(sizes)
)
verdict("contract: ads-r-p3 ticket oracle matches data OK")
