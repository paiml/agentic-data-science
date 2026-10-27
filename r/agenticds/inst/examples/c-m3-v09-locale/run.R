# C-M3 video 9: sort order moves with the locale, accuracy not.
library(agenticds)
d <- na_policy(read_penguins("datasets/penguins/penguins.csv"))
s <- read_split("datasets/fixtures/split.csv")
under <- function(loc, f) {
  old <- Sys.getlocale("LC_COLLATE")
  on.exit(Sys.setlocale("LC_COLLATE", old))
  ok <- Sys.setlocale("LC_COLLATE", loc)
  if (ok == "") stop("locale not installed: ", loc)
  f()
}
srt <- function() paste(sort(c("a", "B", "b", "A")), collapse = " ")
acc <- function() {
  p <- predict_species_clf(
    fit_species_clf(d[s == "train", ]), d[s == "test", ]
  )
  accuracy(factor(d$species[s == "test"], levels = levels(p)), p)
}
sc <- vapply(c("C", "en_US.UTF-8"), under, "", srt)
ac <- vapply(names(sc), under, 0, acc)
cat("sort, C:", sc[[1]], "\nsort, en_US:", sc[[2]], "\n")
print(ac, digits = 17)
stopifnot(sc[[1]] != sc[[2]], ac[[1]] == ac[[2]])
verdict("contract: ads-r-p3 sort moves, accuracy same OK")
