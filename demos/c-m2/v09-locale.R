# C-M2 video 9 (native R): a sort-based split moves with the locale; the row-index folds do not.
source("demos/native-lib.R")
src <- c(
  "ids <- c(\"b1\", \"A2\", \"a3\", \"B4\", \"c5\", \"C6\")",
  "sort_in <- function(loc) { Sys.setlocale(\"LC_COLLATE\", loc); order(ids) }",
  "by_sort <- list(C = sort_in(\"C\"), en = sort_in(\"en_US.utf8\"))",
  "d <- na_policy(read_penguins(\"datasets/penguins/penguins.csv\"))",
  "f <- read_folds(\"datasets/fixtures/folds.csv\")",
  "cv <- sapply(c(\"C\", \"en_US.utf8\"), function(l) {",
  "  Sys.setlocale(\"LC_COLLATE\", l); cv_rmse(d, f, FALSE) })",
  "!identical(by_sort$C, by_sort$en) && identical(cv[[1]], cv[[2]])")
ids <- c("b1", "A2", "a3", "B4", "c5", "C6")
sort_in <- function(loc) { Sys.setlocale("LC_COLLATE", loc); order(ids) }
by_sort <- list(C = sort_in("C"), en = sort_in("en_US.utf8"))
d <- na_policy(read_penguins("datasets/penguins/penguins.csv"))
f <- read_folds("datasets/fixtures/folds.csv")
cv <- sapply(c("C", "en_US.utf8"), function(l) { Sys.setlocale("LC_COLLATE", l); cv_rmse(d, f, FALSE) })
ok <- !identical(by_sort$C, by_sort$en) && identical(cv[[1]], cv[[2]])
nat_show("a sort-based split moves with the locale; row-index folds do not", src)
nat_row("sort order, C", paste(by_sort$C, collapse = " "))
nat_row("sort order, en", paste(by_sort$en, collapse = " "))
nat_row("cv_rmse, C", sprintf("%.17g", cv[[1]]))
nat_row("cv_rmse, en", sprintf("%.17g", cv[[2]]))
nat_verdict(src[8], ok, "contract: c-m2 row-index folds identical across locales OK")
