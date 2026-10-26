# pipeline: validate, split, fit, score; compare to the golden
f <- "datasets/wine-quality/winequality-%s.csv"
res <- pipeline_wine(sprintf(f, "red"), sprintf(f, "white"))
g <- jsonlite::fromJSON("datasets/golden/p4.json")
mine <- c(rmse = res$rmse, r2 = res$r2, unlist(res$mean_quality_by_color))
gold <- c(rmse = g$rmse, r2 = g$r2, unlist(g$mean_quality_by_color))
rbind(mine, gold)
ok <- isTRUE(all.equal(mine, gold, tolerance = 1e-9)) &&
  res$n_train == g$n_train && res$n_test == g$n_test
cat(cli::col_green(cli::style_bold(ok)), "\n")
