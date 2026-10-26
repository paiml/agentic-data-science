# bench: two engines, one answer; timings shown, never asserted
a <- aggregate_dplyr(w); b <- aggregate_data_table(w)
a
b
tm <- bench_wine(w, reps = 5L)
tm
ok <- identical(a$color, b$color) && identical(a$n, b$n) &&
  isTRUE(all.equal(a$mean_quality, b$mean_quality, tolerance = 1e-12))
cat(cli::col_green(cli::style_bold(ok)), "\n")
