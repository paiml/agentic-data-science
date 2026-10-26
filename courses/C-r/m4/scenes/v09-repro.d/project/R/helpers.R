wine <- function(color) {
  sprintf("data/winequality-%s.csv", color)
}

verdict <- function(ok, msg) {
  style <- if (ok) cli::col_green else cli::col_red
  line <- paste0("contract: c-m4 ", msg, ": ", ok)
  cat(style(cli::style_bold(line)), "\n")
  invisible(ok)
}

locale_run <- function(loc, keys) {
  old <- Sys.getlocale("LC_COLLATE")
  on.exit(Sys.setlocale("LC_COLLATE", old))
  Sys.setlocale("LC_COLLATE", loc)
  res <- agenticds::pipeline_wine(wine("red"), wine("white"))
  list(order = order(keys), test = res$n_test, rmse = res$rmse)
}
