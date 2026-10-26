# red: shift the test rows by one and the golden count breaks
g <- jsonlite::fromJSON("datasets/golden/p4.json")
shifted <- function(df) {
  is_test <- seq_len(nrow(df)) %% 5L == 1L
  list(train = df[!is_test, ], test = df[is_test, ])
}
a <- split_wine(w); b <- shifted(w)
c(golden = g$n_test, ours = nrow(a$test), shifted = nrow(b$test))
ok <- nrow(a$test) == g$n_test && nrow(b$test) != g$n_test
cat(cli::col_green(cli::style_bold(ok)), "\n")
