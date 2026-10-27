# C-M3 video 9: sort order moves with the locale, accuracy not.
# Usage (from the repo root): source("<this file>")
raw <- agenticds::read_penguins("datasets/penguins/penguins.csv")
d <- agenticds::na_policy(raw)
s <- agenticds::read_split("datasets/fixtures/split.csv")
under <- function(loc, f) {
  old <- Sys.getlocale("LC_COLLATE")
  on.exit(Sys.setlocale("LC_COLLATE", old))
  if (!nzchar(Sys.setlocale("LC_COLLATE", loc))) stop("no ", loc)
  f()
}
verdict <- agenticds::verdict
srt <- function() paste(sort(c("a", "B", "b", "A")), collapse = " ")
acc <- function() {
  fit <- agenticds::fit_species_clf(d[s == "train", ])
  p <- agenticds::predict_species_clf(fit, d[s == "test", ])
  agenticds::accuracy(d$species[s == "test"], p)
}
sc <- vapply(c("C", "en_US.UTF-8"), under, "", srt)
ac <- vapply(names(sc), under, 0, acc)
cat("sort, C:", sc[[1]], "\nsort, en_US:", sc[[2]], "\n")
print(ac, digits = 17)
stopifnot(sc[[1]] != sc[[2]], ac[[1]] == ac[[2]])
verdict("contract: ads-r-p3 sort moves, accuracy same OK")
