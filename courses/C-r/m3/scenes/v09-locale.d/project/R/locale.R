# v09 locale: sort order moves, accuracy does not
h <- source("R/helpers.R")$value
run_scene <- function() {
  d <- h$load_clean("data/penguins.csv")
  s <- h$read_split("data/split.csv")
  old <- Sys.getlocale("LC_COLLATE")
  on.exit(Sys.setlocale("LC_COLLATE", old))
  srt <- function(loc) {
    Sys.setlocale("LC_COLLATE", loc)
    sort(c("a", "B", "b", "A"))
  }
  acc <- function(loc) {
    Sys.setlocale("LC_COLLATE", loc)
    fit <- h$fit_species_clf(d[s == "train", ])
    pred <- h$predict_species_clf(fit, d[s == "test", ])
    mean(d$species[s == "test"] == pred)
  }
  loc <- c("C", "en_US.UTF-8")
  for (l in loc) cat(l, srt(l), sprintf("%.8f\n", acc(l)))
  differ <- !identical(srt(loc[[1]]), srt(loc[[2]]))
  same <- abs(acc(loc[[1]]) - acc(loc[[2]])) < 1e-12
  h$verdict("contract: c-m3 locale ok: ", differ && same)
}

if (sys.nframe() == 0) run_scene()
