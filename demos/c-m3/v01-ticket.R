# C-M3 video 1 (native R): the ticket's oracle is the golden file p3.json. Run from the repo root.
source("demos/native-lib.R")
src <- c(
  "d <- na_policy(read_penguins(\"datasets/penguins/penguins.csv\"))",
  "g <- jsonlite::fromJSON(\"datasets/golden/p3.json\")",
  "acc <- sum(diag(g$confusion)) / sum(g$confusion)",
  "abs(acc - g$accuracy) < 1e-12 && nrow(d) == sum(g$kmeans$cluster_sizes)")
d <- na_policy(read_penguins("datasets/penguins/penguins.csv"))
g <- jsonlite::fromJSON("datasets/golden/p3.json")
acc <- sum(diag(g$confusion)) / sum(g$confusion)
nat_show("the ticket's oracle: golden/p3.json", src)
nat_row("golden accuracy", sprintf("%.4f = %d/%d", g$accuracy, sum(diag(g$confusion)), sum(g$confusion)))
nat_row("cluster sizes", paste(g$kmeans$cluster_sizes, collapse = "  "))
nat_row("clean rows", sprintf("%d", nrow(d)))
nat_verdict(src[4], abs(acc - g$accuracy) < 1e-12 && nrow(d) == sum(g$kmeans$cluster_sizes),
  "contract: c-m3 ticket oracle consistent with the data OK")
