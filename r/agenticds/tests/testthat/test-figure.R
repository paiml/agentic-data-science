root <- Sys.getenv(
  "ADS_ROOT",
  unset = normalizePath(file.path("..", "..", "..", ".."))
)
fsc <- agenticds::figure_scatter
pen <- agenticds::na_policy(agenticds::read_penguins(
  file.path(root, "datasets", "penguins", "penguins.csv")
))
bill <- function(d = pen, ...) {
  fsc(d, "bill_length_mm", "bill_depth_mm", "t", "x", "y", ...)
}

test_that("figure_scatter refuses empty data, unknown columns", {
  expect_error(bill(pen[0, ]))
  expect_error(fsc(pen, "nope", "bill_depth_mm", "t", "x", "y"))
})

test_that("figure_svg writes a 1280x720 svg", {
  for (grp in list(NULL, "species")) {
    for (fit in c(TRUE, FALSE)) {
      f <- tempfile(fileext = ".svg")
      p <- bill(group = grp, fit = fit)
      expect_identical(figure_svg(p, f), f)
      txt <- paste(readLines(f), collapse = "\n")
      expect_match(txt, "viewBox=\"0 0 1280 720\"", fixed = TRUE)
      expect_match(
        txt, "width=\"1280\" height=\"720\"",
        fixed = TRUE
      )
      expect_false(grepl("<?xml", txt, fixed = TRUE))
    }
  }
})

test_that("figure_svg is deterministic", {
  a <- tempfile(fileext = ".svg")
  b <- tempfile(fileext = ".svg")
  figure_svg(bill(), a)
  figure_svg(bill(), b)
  expect_identical(readLines(a), readLines(b))
})

test_that("figure_svg writes to ADS_OUT, else nothing", {
  d <- tempfile("out-")
  dir.create(d)
  withr::with_envvar(c(ADS_OUT = d), figure_svg(bill()))
  expect_true(file.exists(file.path(d, "plot.svg")))
  withr::with_envvar(
    c(ADS_OUT = ""),
    expect_null(figure_svg(bill()))
  )
})

svg_lines <- function(p) {
  f <- tempfile(fileext = ".svg")
  figure_svg(p, f)
  readLines(f)
}
# Data points are the round-capped filled paths; text is one <use>
# per glyph (the cairo device draws no <text>).
n_points <- function(txt) {
  pat <- "fill-rule:nonzero;fill:rgb.*stroke-linecap:round"
  sum(grepl(pat, txt))
}
n_glyphs <- function(txt) sum(grepl("<use", txt, fixed = TRUE))
chars <- function(...) nchar(paste(c(...), collapse = ""))

test_that("the svg draws one point per row", {
  expect_identical(n_points(svg_lines(bill())), nrow(pen))
  # Grouped: one legend key per species as well.
  g <- bill(group = "species")
  expect_identical(
    n_points(svg_lines(g)),
    nrow(pen) + length(unique(pen$species))
  )
  expect_identical(n_points(svg_lines(bill(pen[1:5, ]))), 5L)
})

test_that("the svg draws the title and both axis labels", {
  txt <- svg_lines(bill())
  blank <- svg_lines(fsc(
    pen, "bill_length_mm", "bill_depth_mm", "", "", ""
  ))
  # One glyph per character of "t", "x" and "y".
  expect_identical(
    n_glyphs(txt) - n_glyphs(blank),
    chars("t", "x", "y")
  )
  long <- svg_lines(fsc(
    pen, "bill_length_mm", "bill_depth_mm",
    "Bill depth on length", "length (mm)", "depth (mm)"
  ))
  expect_identical(
    n_glyphs(long) - n_glyphs(blank),
    chars("Bill depth on length", "length (mm)", "depth (mm)")
  )
})

test_that("the svg draws tick labels on both axes", {
  p <- bill()
  pp <- ggplot2::ggplot_build(p)$layout$panel_params[[1]]
  ticks <- c(pp$x$get_labels(), pp$y$get_labels())
  ticks <- ticks[!is.na(ticks)]
  expect_gt(length(pp$x$get_labels()), 1L)
  expect_gt(length(pp$y$get_labels()), 1L)
  blank <- svg_lines(fsc(
    pen, "bill_length_mm", "bill_depth_mm", "", "", ""
  ))
  expect_gte(n_glyphs(blank), chars(ticks))
  expect_true(any(grepl("stroke:rgb", blank)))
})

test_that("a fit adds a line without adding points", {
  red <- function(p) {
    sum(grepl("stroke:rgb(75", svg_lines(p), fixed = TRUE))
  }
  expect_identical(
    n_points(svg_lines(bill(fit = TRUE))),
    n_points(svg_lines(bill()))
  )
  expect_gt(red(bill(fit = TRUE)), red(bill()))
})

test_that("figure_demo draws every module's figure", {
  d <- tempfile("demo-")
  dir.create(d)
  wine <- nrow(utils::read.csv(file.path(
    root, "datasets", "wine-quality", "winequality-red.csv"
  )))
  ids <- c(
    "c-m1-v01-ticket", "c-m2-v02-ols", "c-m3-v03-red",
    "c-m3-v04-determinism", "c-m4-v02-ingest"
  )
  withr::with_dir(root, withr::with_envvar(c(ADS_OUT = d), {
    for (id in ids) {
      unlink(file.path(d, "plot.svg"))
      figure_demo(id)
      txt <- readLines(file.path(d, "plot.svg"))
      expect_gt(file.size(file.path(d, "plot.svg")), 1000)
      expected <- if (grepl("^c-m4", id)) {
        wine
      } else {
        nrow(pen) + length(unique(pen$species))
      }
      # Every row is a point; axes, title and ticks carry glyphs.
      expect_identical(n_points(txt), expected, info = id)
      expect_gt(n_glyphs(txt), 40L)
    }
  }))
  expect_error(figure_demo("c-m9-v01-x"))
  expect_error(figure_demo("nonsense"))
})
