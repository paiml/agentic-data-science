# C-M3 video 9 (native R): the sort order moves with the locale; the classes and the accuracy do not.
source("demos/native-lib.R")
src <- c(
  "d <- na_policy(read_penguins(\"datasets/penguins/penguins.csv\"))",
  "s <- read_split(\"datasets/fixtures/split.csv\")",
  "acc_in <- function(loc) {",
  "  Sys.setlocale(\"LC_COLLATE\", loc)",
  "  p <- predict_species_clf(fit_species_clf(d[s == \"train\", ]), d[s == \"test\", ])",
  "  accuracy(factor(d$species[s == \"test\"], levels = levels(p)), p) }",
  "srt <- sapply(c(\"C\", \"en_US.utf8\"), function(l) { Sys.setlocale(\"LC_COLLATE\", l)",
  "  paste(sort(c(\"a\", \"B\", \"b\", \"A\")), collapse = \" \") })",
  "acc <- sapply(c(\"C\", \"en_US.utf8\"), acc_in)",
  "srt[[1]] != srt[[2]] && identical(acc[[1]], acc[[2]])")
d <- na_policy(read_penguins("datasets/penguins/penguins.csv"))
s <- read_split("datasets/fixtures/split.csv")
acc_in <- function(loc) {
  Sys.setlocale("LC_COLLATE", loc)
  p <- predict_species_clf(fit_species_clf(d[s == "train", ]), d[s == "test", ])
  accuracy(factor(d$species[s == "test"], levels = levels(p)), p) }
srt <- sapply(c("C", "en_US.utf8"), function(l) { Sys.setlocale("LC_COLLATE", l)
  paste(sort(c("a", "B", "b", "A")), collapse = " ") })
acc <- sapply(c("C", "en_US.utf8"), acc_in)
ok <- srt[[1]] != srt[[2]] && identical(acc[[1]], acc[[2]])
nat_show("the sort order moves with the locale; the accuracy does not", src)
nat_row("sort, C", srt[[1]])
nat_row("sort, en_US", srt[[2]])
nat_row("accuracy, C", sprintf("%.17g", acc[[1]]))
nat_row("accuracy, en_US", sprintf("%.17g", acc[[2]]))
nat_verdict(src[10], ok, "contract: c-m3 locales sort differently, accuracy identical OK")
