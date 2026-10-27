# C-M4 video 4: the whole pipeline, compared with the golden.
# Run from the repo root: source("<this file>")
library(agenticds)
f <- file.path("datasets", "wine-quality", "winequality-%s.csv")
res <- pipeline_wine(sprintf(f, "red"), sprintf(f, "white"))
g <- jsonlite::fromJSON(file.path("datasets", "golden", "p4.json"))
cat(sprintf(
  "rows %d  train %d  test %d\n",
  res$n_rows, res$n_train, res$n_test
))
cat(sprintf("rmse %.4f  r2 %.4f\n", res$rmse, res$r2))
mine <- c(
  rmse = res$rmse, r2 = res$r2, unlist(res$mean_quality_by_color)
)
gold <- c(
  rmse = g$rmse, r2 = g$r2, unlist(g$mean_quality_by_color)
)
print(rbind(mine, gold), digits = 6)
stopifnot(
  res$n_train == g$n_train, res$n_test == g$n_test,
  isTRUE(all.equal(mine, gold, tolerance = 1e-9))
)
verdict("contract: ads-r-p4 pipeline rmse and r2 match golden OK")
