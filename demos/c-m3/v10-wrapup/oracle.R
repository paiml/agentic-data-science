# what the gate proved: both P3 examples hold their contract
fit <- fit_species_clf(d[s == "train", ])
pred <- predict_species_clf(fit, d[s == "test", ])
truth <- factor(d$species[s == "test"], levels = levels(pred))
km <- kmeans_fixed(d, cen)
checks <- c(tree = isTRUE(all.equal(accuracy(truth, pred), g$accuracy)),
  kmeans = isTRUE(all.equal(km$objective, g$kmeans$objective)))
checks
ok <- all(checks)
cat(cli::col_green(cli::style_bold(ok)), "\n")
