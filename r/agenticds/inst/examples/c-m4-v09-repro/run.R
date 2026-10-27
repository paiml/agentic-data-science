# C-M4 video 9: a split by row index does not move with locale.
# Usage (from the repo root): source("<this file>")
ids <- c("b1", "A2", "a3", "B4", "c5", "C6")
f <- file.path("datasets", "wine-quality", "winequality-%s.csv")
w <- sprintf(f, c("red", "white"))
under <- function(loc, code) {
  old <- Sys.getlocale("LC_COLLATE")
  on.exit(Sys.setlocale("LC_COLLATE", old))
  if (!nzchar(Sys.setlocale("LC_COLLATE", loc))) stop("no ", loc)
  code()
}
en <- "en_US.UTF-8"
ord <- function() order(ids)
run <- function() agenticds::pipeline_wine(w[1], w[2])$rmse
o <- rbind(C = under("C", ord), en_US = under(en, ord))
print(o)
r <- c(C = under("C", run), en_US = under(en, run))
print(r, digits = 17)
stopifnot(!identical(o[1, ], o[2, ]), r[["C"]] == r[["en_US"]])
agenticds::verdict(
  "contract: ads-r-p4 rmse identical in two locales OK"
)
