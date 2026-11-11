#' A real-axes scatter figure: title, labelled axes, ticks, grid.
#' @param d A data frame.
#' @param x,y Column names of the two numeric axes.
#' @param title,xlab,ylab Title and axis labels (with units).
#' @param group Optional column name coloured per group.
#' @param fit Draw the least-squares line over all points.
#' @return A ggplot object (fixed theme, colours and font).
#' @export
figure_scatter <- function(d, x, y, title, xlab, ylab,
                           group = NULL, fit = FALSE) {
  stopifnot(
    is.data.frame(d), nrow(d) > 0L,
    x %in% names(d), y %in% names(d)
  )
  .data <- ggplot2::.data
  aes <- if (is.null(group)) {
    ggplot2::aes(x = .data[[x]], y = .data[[y]])
  } else {
    ggplot2::aes(
      x = .data[[x]], y = .data[[y]], colour = .data[[group]]
    )
  }
  dots <- if (is.null(group)) {
    ggplot2::geom_point(size = 2, alpha = 0.7, colour = "#1f4e79")
  } else {
    ggplot2::geom_point(size = 2, alpha = 0.7)
  }
  p <- ggplot2::ggplot(d, aes) + dots
  if (fit) {
    p <- p + ggplot2::geom_smooth(
      ggplot2::aes(colour = NULL),
      method = "lm",
      formula = y ~ x, se = FALSE, colour = "#c0392b",
      linewidth = 1
    )
  }
  p +
    ggplot2::labs(
      title = title, x = xlab, y = ylab, colour = NULL
    ) +
    ggplot2::theme_minimal(base_size = 18, base_family = "sans") +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_line(colour = "grey92")
    )
}

#' Write a figure as a plain <svg>, 1280 x 720, to `file`.
#'
#' With no `file` the path is `$ADS_OUT/plot.svg`; with neither,
#' nothing is written.
#' @param p A ggplot object.
#' @param file Output path or NULL.
#' @return The path written, or NULL, invisibly.
#' @export
figure_svg <- function(p, file = NULL) {
  out <- Sys.getenv("ADS_OUT", unset = "")
  if (is.null(file) && nzchar(out)) {
    file <- file.path(out, "plot.svg")
  }
  if (is.null(file)) {
    return(invisible(NULL))
  }
  # The cairo svg() device: always present and deterministic.
  grDevices::svg(file, width = 1280 / 72, height = 720 / 72)
  print(p)
  grDevices::dev.off()
  txt <- readLines(file)
  txt <- txt[!startsWith(txt, "<?xml")]
  # A double-quoted px header, which the SVG-to-PNG step reads.
  head <- startsWith(txt, "<svg")
  txt[head] <- paste0(
    "<svg xmlns=\"http://www.w3.org/2000/svg\" ",
    "xmlns:xlink=\"http://www.w3.org/1999/xlink\" ",
    "width=\"1280\" height=\"720\" viewBox=\"0 0 1280 720\">"
  )[seq_len(sum(head))]
  writeLines(txt, file)
  invisible(file)
}

#' The lesson figure for one demo, from the lesson's own dataset.
#'
#' Modules 1-3 plot the cleaned penguins (a column pair that
#' rotates with the video number); module 4 plots red-wine alcohol
#' against quality with its fit line. Run from the repo root.
#' @param id Example id such as "c-m2-v03-red".
#' @return The path written, or NULL, invisibly.
#' @export
figure_demo <- function(id) {
  p <- demo_plot(id)
  figure_svg(p)
}

# The ggplot behind figure_demo, so a test can render it any way.
demo_plot <- function(id) {
  m <- as.integer(sub("^c-m([0-9]).*$", "\\1", id))
  v <- suppressWarnings(
    as.integer(sub("^c-m[0-9]-[vp]([0-9]+).*$", "\\1", id))
  )
  stopifnot(!is.na(m), m %in% 1:4, !is.na(v))
  if (m == 4L) {
    w <- utils::read.csv(
      file.path("datasets", "wine-quality", "winequality-red.csv")
    )
    return(figure_scatter(
      w, "alcohol", "quality", "Wine quality on alcohol",
      "alcohol (% vol)", "quality score (0-10)",
      fit = TRUE
    ))
  }
  csv <- file.path("datasets", "penguins", "penguins.csv")
  d <- agenticds::na_policy(agenticds::read_penguins(csv))
  pairs <- list(
    c(
      "bill_length_mm", "bill_depth_mm",
      "bill length (mm)", "bill depth (mm)"
    ),
    c(
      "flipper_length_mm", "body_mass_g",
      "flipper length (mm)", "body mass (g)"
    ),
    c(
      "bill_length_mm", "flipper_length_mm",
      "bill length (mm)", "flipper length (mm)"
    )
  )
  pr <- pairs[[(v + m) %% length(pairs) + 1L]]
  nm <- function(s) sub(" \\(.*", "", s)
  figure_scatter(
    d, pr[1], pr[2], paste(nm(pr[4]), "on", nm(pr[3])),
    pr[3], pr[4],
    group = "species", fit = (m == 2L)
  )
}
