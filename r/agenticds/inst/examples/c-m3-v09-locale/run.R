# C-M3 video 9: sort order moves with the locale, accuracy not.
# Usage (from the repo root): source("this file")
library(agenticds)
d <- na_policy(read_penguins("datasets/penguins/penguins.csv"))
s <- read_split("datasets/fixtures/split.csv")
old <- Sys.getlocale("LC_COLLATE")
under <- function(loc, f) {
  Sys.setlocale("LC_COLLATE", loc)
  f()
}
srt <- function() paste(sort(c("a", "B", "b", "A")), collapse = " ")
acc <- function() {
  p <- predict_species_clf(
    fit_species_clf(d[s == "train", ]), d[s == "test", ]
  )
  accuracy(factor(d$species[s == "test"], levels = levels(p)), p)
}
loc <- c("C", "en_US.utf8")
sc <- vapply(loc, under, "", srt)
ac <- vapply(loc, under, 0, acc)
invisible(Sys.setlocale("LC_COLLATE", old))
cat("sort, C:", sc[[1]], "\nsort, en_US:", sc[[2]], "\n")
cat(sprintf("accuracy, C: %.17g\n", ac[[1]]))
cat(sprintf("accuracy, en_US: %.17g\n", ac[[2]]))
stopifnot(sc[[1]] != sc[[2]], ac[[1]] == ac[[2]])
verdict("contract: ads-r-p3 sort moves, accuracy same OK")
