# the sort order moves with the locale; the accuracy does not
sorted <- function(loc) { Sys.setlocale("LC_COLLATE", loc)
  paste(sort(c("a", "B", "b", "A")), collapse = " ") }
acc_in <- function(loc) { Sys.setlocale("LC_COLLATE", loc)
  fit <- fit_species_clf(d[s == "train", ])
  p <- predict_species_clf(fit, d[s == "test", ])
  mean(d$species[s == "test"] == p) }
loc <- c("C", "en_US.utf8")
sapply(loc, sorted)
sapply(loc, acc_in)
ok <- sorted(loc[1]) != sorted(loc[2]) &&
  identical(acc_in(loc[1]), acc_in(loc[2]))
cat(cli::col_green(cli::style_bold(ok)), "\n")
