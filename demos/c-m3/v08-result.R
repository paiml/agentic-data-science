# C-M3 video 8 (native R): the fixed-centroid k-means result matches the golden sizes and objective.
source("demos/native-lib.R")
src <- c(
  "d <- na_policy(read_penguins(\"datasets/penguins/penguins.csv\"))",
  "g <- jsonlite::fromJSON(\"datasets/golden/p3.json\")",
  "cen <- read_centroids(\"datasets/fixtures/centroids.csv\")",
  "km <- kmeans_fixed(d, cen)",
  "sizes <- as.integer(table(km$cluster))",
  "same <- identical(sizes, as.integer(g$kmeans$cluster_sizes))",
  "same && abs(km$objective - g$kmeans$objective) < 1e-9")
d <- na_policy(read_penguins("datasets/penguins/penguins.csv"))
g <- jsonlite::fromJSON("datasets/golden/p3.json")
cen <- read_centroids("datasets/fixtures/centroids.csv")
km <- kmeans_fixed(d, cen)
sizes <- as.integer(table(km$cluster))
same <- identical(sizes, as.integer(g$kmeans$cluster_sizes))
ok <- same && abs(km$objective - g$kmeans$objective) < 1e-9
nat_show("k-means from fixed centroids, against the golden result", src)
nat_row("cluster sizes", paste(sizes, collapse = "  "))
nat_row("objective", sprintf("%.2f", km$objective))
nat_row("golden", sprintf("%s   %.2f", paste(g$kmeans$cluster_sizes, collapse = "  "), g$kmeans$objective))
nat_verdict(src[7], ok, "contract: c-m3 cluster sizes and objective match golden OK")
