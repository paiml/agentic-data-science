# fixed split, fixed centroids: every run is identical
run <- function() list(p = predict_species_clf(fit, d[s == "test", ]),
                       km = kmeans_fixed(d, cen))
a <- run(); b <- run()
identical(a, b)
set.seed(1); before <- .Random.seed
invisible(kmeans_fixed(d, cen))
identical(before, .Random.seed)
ok <- identical(a, b) && identical(before, .Random.seed)
cat(cli::col_green(cli::style_bold(ok)), "\n")
