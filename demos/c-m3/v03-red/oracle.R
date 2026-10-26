# invert the accuracy test: the golden oracle must go red
broken <- mean(truth != pred)
c(golden = g$accuracy, broken = broken)
r <- all.equal(broken, g$accuracy, tolerance = 1e-9)
cat(cli::col_red(r), "\n")
ok <- !isTRUE(r)
cat(cli::col_green(cli::style_bold(ok)), "\n")
