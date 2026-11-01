anscombe_sets <- c("I", "II", "III", "IV")

#' Read Anscombe's quartet (long form: set, x, y).
#' @param path Path to data/anscombe.csv.
#' @return A tibble with 44 rows and columns set, x, y.
#' @export
anscombe_read <- function(path) {
  d <- readr::read_csv(
    path,
    col_types = readr::cols(set = "c", x = "d", y = "d")
  )
  stopifnot(
    nrow(d) == 44L,
    identical(unique(d$set), anscombe_sets)
  )
  d
}

#' Summary statistics of each set of the quartet.
#' @param d The tibble from anscombe_read.
#' @return One row per set: n, mean and variance of x and y,
#'   correlation, least-squares slope and intercept.
#' @export
anscombe_summary <- function(d) {
  rows <- lapply(anscombe_sets, function(s) {
    v <- d[d$set == s, ]
    fit <- stats::lm(y ~ x, data = v)
    tibble::tibble(
      set = s, n = nrow(v),
      mean_x = mean(v$x), mean_y = mean(v$y),
      var_x = stats::var(v$x), var_y = stats::var(v$y),
      cor = stats::cor(v$x, v$y),
      slope = unname(stats::coef(fit)[[2]]),
      intercept = unname(stats::coef(fit)[[1]])
    )
  })
  do.call(rbind, rows)
}

#' The stdout.txt text: one line per set, 2 decimals (parity).
#' @param s The tibble from anscombe_summary.
#' @return A character vector of lines.
#' @export
anscombe_lines <- function(s) {
  f <- function(z) formatC(z, format = "f", digits = 2L)
  sprintf(
    "set %s: n=%d mean_x=%s mean_y=%s slope=%s intercept=%s r=%s",
    s$set, s$n, f(s$mean_x), f(s$mean_y), f(s$slope),
    f(s$intercept), f(s$cor)
  )
}

#' The plot: four panels, scatter with the least-squares line.
#' @param d The tibble from anscombe_read.
#' @return A ggplot object (fixed theme, colours and limits).
#' @export
anscombe_plot <- function(d) {
  d$set <- factor(d$set, levels = anscombe_sets)
  ggplot2::ggplot(d, ggplot2::aes(x = d[["x"]], y = d[["y"]])) +
    ggplot2::geom_point(colour = "#1f4e79", size = 2) +
    ggplot2::geom_smooth(
      method = "lm", formula = y ~ x, se = FALSE,
      colour = "#c0392b", linewidth = 0.7
    ) +
    ggplot2::labs(x = "x", y = "y") +
    ggplot2::facet_wrap(~set, nrow = 2) +
    ggplot2::coord_cartesian(xlim = c(3, 20), ylim = c(2, 14)) +
    ggplot2::theme_minimal(base_size = 18, base_family = "sans")
}

#' Write the plot as a plain <svg>, 960 x 720 (the hero panel).
#' @param d The tibble from anscombe_read.
#' @param file Output path.
#' @return The path, invisibly.
#' @export
anscombe_svg <- function(d, file) {
  svglite::svglite(file, width = 960 / 72, height = 720 / 72)
  print(anscombe_plot(d))
  grDevices::dev.off()
  txt <- readLines(file)
  writeLines(txt[!startsWith(txt, "<?xml")], file)
  invisible(file)
}
