# the ticket's oracle: the golden file p3.json
g <- jsonlite::fromJSON("datasets/golden/p3.json")
cm <- g$confusion
acc <- sum(diag(cm)) / sum(cm)
c(sum(diag(cm)), sum(cm), acc)
g$kmeans$cluster_sizes
nrow(d)
ok <- abs(acc - g$accuracy) < 1e-12 &&
  nrow(d) == sum(g$kmeans$cluster_sizes)
cat(cli::col_green(cli::style_bold(ok)), "\n")
