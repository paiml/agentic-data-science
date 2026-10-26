# the ticket: golden/p4.json is the oracle for the wine pipeline
g <- jsonlite::fromJSON("datasets/golden/p4.json")
str(g, give.attr = FALSE)
n <- nrow(w)
n_test <- n %/% 5L
ok <- g$n_rows == n && g$n_test == n_test &&
  g$n_train == n - n_test
cat(cli::col_green(cli::style_bold(ok)), "\n")
