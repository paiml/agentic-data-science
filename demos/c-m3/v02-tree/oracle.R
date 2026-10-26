# the tree on the fixed split reproduces the golden matrix
fit <- fit_species_clf(d[s == "train", ])
pred <- predict_species_clf(fit, d[s == "test", ])
truth <- factor(d$species[s == "test"], levels = levels(pred))
cm <- confusion(truth, pred)
cm
acc <- accuracy(truth, pred)
acc
ok <- isTRUE(all.equal(acc, g$accuracy)) && all(cm == g$confusion)
cat(cli::col_green(cli::style_bold(ok)), "\n")
