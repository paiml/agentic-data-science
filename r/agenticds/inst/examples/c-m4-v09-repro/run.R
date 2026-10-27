# C-M4 video 9: a split by row index does not move with locale.
# Run from the repo root: source("<this file>")
library(agenticds)
ids <- c("b1", "A2", "a3", "B4", "c5", "C6")
old <- Sys.getlocale("LC_COLLATE")
on.exit(Sys.setlocale("LC_COLLATE", old))
ord <- function(l) {
  Sys.setlocale("LC_COLLATE", l)
  order(ids)
}
print(rbind(C = ord("C"), en_US = ord("en_US.UTF-8")))
f <- file.path("datasets", "wine-quality", "winequality-%s.csv")
run <- function(l) {
  Sys.setlocale("LC_COLLATE", l)
  pipeline_wine(sprintf(f, "red"), sprintf(f, "white"))$rmse
}
r <- c(C = run("C"), en_US = run("en_US.UTF-8"))
print(r, digits = 17)
stopifnot(
  !identical(ord("C"), ord("en_US.UTF-8")),
  r[["C"]] == r[["en_US"]]
)
verdict("contract: ads-r-p4 rmse identical in two locales OK")
