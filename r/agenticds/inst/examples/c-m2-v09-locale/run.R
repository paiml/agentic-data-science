# C-M2 video 9: a sort-based split moves with the locale.
# Usage (from the repo root): source("<this file>")
ids <- c("b1", "A2", "a3", "B4", "c5", "C6")
raw <- agenticds::read_penguins("datasets/penguins/penguins.csv")
d <- agenticds::na_policy(raw)
f <- agenticds::read_folds("datasets/fixtures/folds.csv")
under <- function(loc) {
  old <- Sys.getlocale("LC_COLLATE")
  on.exit(Sys.setlocale("LC_COLLATE", old))
  if (!nzchar(Sys.setlocale("LC_COLLATE", loc))) stop("no ", loc)
  list(order = order(ids), cv = agenticds::cv_rmse(d, f, FALSE))
}
by_loc <- lapply(c("C", "en_US.UTF-8"), under)
cat("order under C:    ", by_loc[[1]]$order, "\n")
cat("order under en_US:", by_loc[[2]]$order, "\n")
cat(sprintf("cv_rmse under C:     %.5f\n", by_loc[[1]]$cv))
cat(sprintf("cv_rmse under en_US: %.5f\n", by_loc[[2]]$cv))
stopifnot(
  !identical(by_loc[[1]]$order, by_loc[[2]]$order),
  identical(by_loc[[1]]$cv, by_loc[[2]]$cv)
)
agenticds::verdict(
  "contract: ads-r-p2 row-index folds locale-proof OK"
)
