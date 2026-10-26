# k-means from fixed centroids, against the golden result
km <- kmeans_fixed(d, cen)
sizes <- tabulate(km$cluster, nbins = nrow(cen))
sizes
km$objective
g$kmeans$objective
ok <- identical(sizes, as.integer(g$kmeans$cluster_sizes)) &&
  abs(km$objective - g$kmeans$objective) < 1e-9
cat(cli::col_green(cli::style_bold(ok)), "\n")
