# c-m4 v01: the ticket's oracle, checked against the data
h <- new.env()
sys.source("R/helpers.R", h)
library(agenticds)

run_scene <- function() {
  stopifnot(h$check_sums("data"))
  g <- jsonlite::fromJSON("data/p4.json")
  str(g)
  w <- read_wine(h$wine("red"), h$wine("white"))
  n <- nrow(w)
  n_test <- n %/% 5
  ok <- g$n_rows == n && g$n_test == n_test &&
    g$n_train == n - n_test
  msg <- sprintf("ticket oracle holds for %d rows", n)
  h$verdict(ok, msg)
}

if (sys.nframe() == 0) run_scene()
