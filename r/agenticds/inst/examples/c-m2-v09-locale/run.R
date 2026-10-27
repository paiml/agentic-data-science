# C-M2 video 9: a sort-based split moves with the locale.
# Usage (from the repo root): source("<this file>")
library(agenticds)
ids <- c("b1", "A2", "a3", "B4", "c5", "C6")
d <- na_policy(read_penguins("datasets/penguins/penguins.csv"))
f <- read_folds("datasets/fixtures/folds.csv")
old <- Sys.getlocale("LC_COLLATE")
by_loc <- lapply(c("C", "en_US.utf8"), function(loc) {
  Sys.setlocale("LC_COLLATE", loc)
  list(order = order(ids), cv = cv_rmse(d, f, FALSE))
})
invisible(Sys.setlocale("LC_COLLATE", old))
cat("order under C:    ", by_loc[[1]]$order, "\n")
cat("order under en_US:", by_loc[[2]]$order, "\n")
cat(sprintf("cv_rmse under C:     %.5f\n", by_loc[[1]]$cv))
cat(sprintf("cv_rmse under en_US: %.5f\n", by_loc[[2]]$cv))
stopifnot(
  !identical(by_loc[[1]]$order, by_loc[[2]]$order),
  identical(by_loc[[1]]$cv, by_loc[[2]]$cv)
)
verdict("contract: ads-r-p2 row-index folds locale-proof OK")
