# C-M3 video 6: two planted mutants of kmeans_fixed must die.
# Usage (from the repo root): source("this file")
raw <- agenticds::read_penguins("datasets/penguins/penguins.csv")
d <- agenticds::na_policy(raw)
g <- jsonlite::fromJSON("datasets/golden/p3.json")
cen <- agenticds::read_centroids("datasets/fixtures/centroids.csv")
src <- paste(deparse(agenticds::kmeans_fixed), collapse = "\n")
mutant <- function(from, to) {
  f <- eval(parse(text = sub(from, to, src, fixed = TRUE)))
  environment(f) <- environment(agenticds::kmeans_fixed)
  f
}
passes <- function(f) {
  km <- f(d, cen)
  same <- tabulate(km$cluster, 3L) == g$kmeans$cluster_sizes
  all(same) &&
    abs(km$objective - g$kmeans$objective) < 1e-9
}
m1 <- mutant("scale = spread)", "scale = spread * 2)")
m2 <- mutant("))^2)", ")))")
cat("scale * 2:", if (passes(m1)) "SURVIVED" else "killed", "\n")
cat("no square:", if (passes(m2)) "SURVIVED" else "killed", "\n")
stopifnot(passes(agenticds::kmeans_fixed), !passes(m1), !passes(m2))
agenticds::verdict("contract: ads-r-p3 2 of 2 mutants killed OK")
