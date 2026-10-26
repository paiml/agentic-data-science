# C-M2 video 1 (native R): the ticket's oracle is the golden file. Run from the repo root.
source("demos/native-lib.R")
src <- c(
  "g <- jsonlite::fromJSON(\"datasets/golden/p2.json\")",
  "names(g)",
  "unlist(g$ols)",
  "all(c(\"ols\", \"species_model\", \"metrics\", \"cv_rmse\") %in% names(g))")
g <- jsonlite::fromJSON("datasets/golden/p2.json")
nat_show("the ticket's oracle: golden/p2.json holds the numbers to hit", src)
nat_row("names(g)", paste(names(g), collapse = "  "))
nat_row("g$ols", sprintf("intercept %.2f   slope %.4f", g$ols$intercept, g$ols$slope))
nat_verdict(src[4], all(c("ols", "species_model", "metrics", "cv_rmse") %in% names(g)),
  "contract: c-m2 ticket oracle present OK")
