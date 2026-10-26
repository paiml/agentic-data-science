# C-M3 video 4 (native R): fixed split and fixed centroids make every run identical; k-means draws no random numbers.
source("demos/native-lib.R")
src <- c(
  "d <- na_policy(read_penguins(\"datasets/penguins/penguins.csv\"))",
  "s <- read_split(\"datasets/fixtures/split.csv\")",
  "cen <- read_centroids(\"datasets/fixtures/centroids.csv\")",
  "fit <- fit_species_clf(d[s == \"train\", ])",
  "run <- function() list(p = predict_species_clf(fit, d[s == \"test\", ]),",
  "                       km = kmeans_fixed(d, cen))",
  "a <- run(); b <- run()",
  "set.seed(1); before <- .Random.seed; invisible(kmeans_fixed(d, cen))",
  "identical(a, b) && identical(before, .Random.seed)")
d <- na_policy(read_penguins("datasets/penguins/penguins.csv"))
s <- read_split("datasets/fixtures/split.csv")
cen <- read_centroids("datasets/fixtures/centroids.csv")
fit <- fit_species_clf(d[s == "train", ])
run <- function() list(p = predict_species_clf(fit, d[s == "test", ]), km = kmeans_fixed(d, cen))
a <- run(); b <- run()
set.seed(1); before <- .Random.seed; invisible(kmeans_fixed(d, cen))
same <- identical(a, b); norng <- identical(before, .Random.seed)
nat_show("fixed split, fixed centroids: every run identical", src)
nat_row("split", paste(names(table(s)), as.integer(table(s)), collapse = "  "))
nat_row("run 1 = run 2", as.character(same))
nat_row("RNG untouched", as.character(norng))
nat_verdict(src[9], same && norng, "contract: c-m3 deterministic; k-means consumes no RNG OK")
