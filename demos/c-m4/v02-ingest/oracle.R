# ingest: both colours bound, each defect class rejected
table(w$color)
bad <- list(na = w, q = w, col = w)
bad$na$alcohol[1] <- NA
bad$q$quality[1] <- 11L
bad$col$color[1] <- "rose"
msg <- sapply(bad, \(x) tryCatch(
  {validate_wine(x); ""}, error = conditionMessage))
msg
ok <- identical(validate_wine(w), w) && all(nzchar(msg)) &&
  nrow(w) == 6497L
cat(cli::col_green(cli::style_bold(ok)), "\n")
