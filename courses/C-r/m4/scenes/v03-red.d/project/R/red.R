# c-m4 v03: break the split, the oracle goes red
h <- new.env()
sys.source("R/helpers.R", h)
library(agenticds)

run_scene <- function() {
  w <- read_wine(h$wine("red"), h$wine("white"))
  g <- jsonlite::fromJSON("data/p4.json")
  good <- nrow(split_wine(w)$test)
  bad <- sum(seq_len(nrow(w)) %% 4L == 0L)
  cat("golden n_test:", g$n_test, "\n")
  cat("split_wine:   ", good, "\n")
  cat(cli::col_red(paste("broken (1 in 4):", bad)), "\n")
  ok <- good == g$n_test && bad != g$n_test
  h$verdict(ok, "bug caught")
}

if (sys.nframe() == 0) run_scene()
