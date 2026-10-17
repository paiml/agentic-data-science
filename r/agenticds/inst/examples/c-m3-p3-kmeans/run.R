# P3 (b): k-means from fixed centroids. Usage: ADS_ROOT=/path/to/repo Rscript run.R
root <- Sys.getenv("ADS_ROOT", unset = ".")
library(agenticds)
d <- na_policy(read_penguins(file.path(root, "datasets", "penguins", "penguins.csv")))
km <- kmeans_fixed(d, read_centroids(file.path(root, "datasets", "fixtures", "centroids.csv")))
cat("objective:", km$objective, "\n")
print(table(km$cluster))
