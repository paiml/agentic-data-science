# C-M4 video 9: a split by row index does not move with locale.
library(agenticds)
ids <- c("b1", "A2", "a3", "B4", "c5", "C6")
f <- file.path("datasets", "wine-quality", "winequality-%s.csv")
under <- function(loc, code) {
  old <- Sys.getlocale("LC_COLLATE")
  on.exit(Sys.setlocale("LC_COLLATE", old))
  ok <- Sys.setlocale("LC_COLLATE", loc)
  if (ok == "") stop("locale not installed: ", loc)
  code()
}
en <- "en_US.UTF-8"
ord <- function() order(ids)
run <- function() {
  pipeline_wine(sprintf(f, "red"), sprintf(f, "white"))$rmse
}
print(rbind(C = under("C", ord), en_US = under(en, ord)))
r <- c(C = under("C", run), en_US = under(en, run))
print(r, digits = 17)
stopifnot(
  !identical(under("C", ord), under(en, ord)),
  r[["C"]] == r[["en_US"]]
)
verdict("contract: ads-r-p4 rmse identical in two locales OK")
