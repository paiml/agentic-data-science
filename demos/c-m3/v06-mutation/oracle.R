# two mutants of kmeans_fixed: the golden result must catch both
src <- paste(deparse(kmeans_fixed), collapse = "\n")
m1 <- eval(parse(text = sub("^2)", ")", src, fixed = TRUE)))
m2 <- eval(parse(text = sub("scale = spread)", "scale = spread * 2)",
  src, fixed = TRUE)))
dies <- function(f) abs(f(d, cen)$objective - g$kmeans$objective) > 1e-9
c(no_square = dies(m1), double_scale = dies(m2))
ok <- dies(m1) && dies(m2)
cat(cli::col_green(cli::style_bold(ok)), "\n")
