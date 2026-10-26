# v09: sorted ids shift with locale, row folds do not
h <- new.env()
sys.source("R/helpers.R", envir = h)

run_scene <- function() {
  d <- h$load_clean("data/penguins.csv")
  f <- h$read_folds("data/folds.csv")
  ids <- h$make_ids(nrow(d))
  cl <- h$locale_run("C", ids, d, f)
  us <- h$locale_run("en_US.UTF-8", ids, d, f)
  cat("CV by row, C: ", format(cl$row, digits = 8), "\n")
  cat("CV by row, US:", format(us$row, digits = 8), "\n")
  cat("CV by id,  C: ", format(cl$by_id, digits = 8), "\n")
  cat("CV by id,  US:", format(us$by_id, digits = 8), "\n")
  moved <- !identical(cl$by_id, us$by_id)
  ok <- moved && identical(cl$row, us$row)
  h$verdict("id folds move, row folds hold", ok)
}

if (sys.nframe() == 0 && !run_scene()) quit(status = 1)
