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

# The content checks render with svglite, which keeps real <text>
# elements and <circle> markers, so labels and ticks are read as
# strings and no font or glyph table is involved.
svg_txt <- function(p) {
  f <- tempfile(fileext = ".svg")
  svglite::svglite(f, width = 1280 / 72, height = 720 / 72)
  print(p)
  grDevices::dev.off()
  readLines(f)
}
attr_of <- function(el, a) {
  sub(paste0(".* ", a, "='([^']*)'.*"), "\\1", el)
}
circles <- function(txt) {
  el <- txt[grepl("^<circle ", txt)]
  cbind(
    x = as.numeric(attr_of(el, "cx")),
    y = as.numeric(attr_of(el, "cy"))
  )
}
texts <- function(txt) {
  el <- txt[grepl("^<text ", txt)]
  # A rotated label is placed by translate(); the rest by x and y.
  pos <- ifelse(
    grepl("translate(", el, fixed = TRUE),
    sub("^<text transform=.translate\\(([^)]*)\\).*", "\\1", el),
    sub("^<text x=.([0-9.]+). y=.([0-9.]+).*", "\\1,\\2", el)
  )
  xy <- do.call(rbind, strsplit(pos, ","))
  data.frame(
    label = sub("^<text [^>]*>(.*)</text>$", "\\1", el),
    x = as.numeric(xy[, 1]),
    y = as.numeric(xy[, 2]),
    rot = grepl("rotate(", el, fixed = TRUE)
  )
}
# Title: the top line; x label: the bottom unrotated line; y label:
# the rotated line; everything else is a tick label or a legend.
label_of <- function(txt, k) {
  t <- texts(txt)
  r <- switch(k,
    title = t[t$y == min(t$y), ],
    xlab = t[!t$rot & t$y == max(t$y), ],
    ylab = t[t$rot, ]
  )
  stopifnot(nrow(r) == 1L)
  r$label
}
tick_labels <- function(txt) {
  t <- texts(txt)
  t[!t$rot & t$y > min(t$y) & t$y < max(t$y), "label"]
}
ticks_of <- function(p) {
  pp <- ggplot2::ggplot_build(p)$layout$panel_params[[1]]
  c(pp$x$get_labels(), pp$y$get_labels())
}
rho <- function(a, b) stats::cor(a, b, method = "spearman")

test_that("the svg draws one point per row, inside the panel", {
  expect_identical(nrow(circles(svg_txt(bill()))), nrow(pen))
  # Grouped: one legend key per species as well.
  g <- svg_txt(bill(group = "species"))
  expect_identical(
    nrow(circles(g)), nrow(pen) + length(unique(pen$species))
  )
  expect_identical(nrow(circles(svg_txt(bill(pen[1:5, ])))), 5L)
  xy <- circles(svg_txt(bill()))
  expect_true(all(xy[, "x"] > 60 & xy[, "x"] < 1280))
  expect_true(all(xy[, "y"] > 30 & xy[, "y"] < 690))
  # Spread over the frame, not collapsed to a point or a line.
  expect_gt(diff(range(xy[, "x"])), 0.2 * 1280)
  expect_gt(diff(range(xy[, "y"])), 0.2 * 720)
})

test_that("the points sit where the data says", {
  # x grows rightwards, y grows upwards (svg y runs downwards).
  xy <- circles(svg_txt(bill()))
  expect_gt(rho(xy[, "x"], pen$bill_length_mm), 0.999)
  expect_lt(rho(xy[, "y"], pen$bill_depth_mm), -0.999)
  # Swapped axes, shuffled y and a transposed scatter all fail.
  expect_lt(abs(rho(xy[, "x"], pen$bill_depth_mm)), 0.99)
  expect_lt(abs(rho(xy[, "y"], pen$bill_length_mm)), 0.99)
  expect_lt(abs(rho(xy[, "y"], rev(pen$bill_depth_mm))), 0.99)
  w <- utils::read.csv(file.path(
    root, "datasets", "wine-quality", "winequality-red.csv"
  ))
  wp <- circles(svg_txt(fsc(w, "alcohol", "pH", "t", "x", "y")))
  expect_gt(rho(wp[, "x"], w$alcohol), 0.999)
  expect_lt(rho(wp[, "y"], w$pH), -0.999)
})

test_that("the title and each axis label read back exactly", {
  txt <- svg_txt(fsc(
    pen, "bill_length_mm", "bill_depth_mm",
    "Bill depth on length", "length (mm)", "depth (mm)"
  ))
  expect_identical(label_of(txt, "title"), "Bill depth on length")
  expect_identical(label_of(txt, "xlab"), "length (mm)")
  expect_identical(label_of(txt, "ylab"), "depth (mm)")
  # Swapped labels are caught: each lands on its own axis.
  sw <- svg_txt(fsc(
    pen, "bill_length_mm", "bill_depth_mm",
    "t", "depth (mm)", "length (mm)"
  ))
  expect_identical(label_of(sw, "xlab"), "depth (mm)")
  expect_identical(label_of(sw, "ylab"), "length (mm)")
})

test_that("the svg draws exactly the tick labels of both axes", {
  p <- bill()
  want <- ticks_of(p)
  want <- want[!is.na(want)]
  expect_gt(length(want), 3L)
  expect_identical(
    sort(tick_labels(svg_txt(p))), sort(as.character(want))
  )
})

test_that("a fit adds exactly one line, with the lm slope sign", {
  fit_line <- function(p) {
    el <- svg_txt(p)
    is_fit <- grepl("^<polyline ", el) &
      grepl("#C0392B", el, fixed = TRUE)
    el[is_fit]
  }
  slope_sign <- function(el) {
    rx <- ".* points='([^']*)'.*"
    pts <- strsplit(sub(rx, "\\1", el), " ")[[1]]
    m <- do.call(rbind, strsplit(pts, ","))
    storage.mode(m) <- "double"
    # svg y runs downwards: the data slope is the negated pixel one.
    -sign(stats::coef(stats::lm(m[, 2] ~ m[, 1]))[[2]])
  }
  lm_sign <- function(d, x, y) {
    sign(stats::coef(stats::lm(d[[y]] ~ d[[x]]))[[2]])
  }
  expect_length(fit_line(bill()), 0L)
  expect_identical(
    nrow(circles(svg_txt(bill(fit = TRUE)))), nrow(pen)
  )
  neg <- fit_line(bill(fit = TRUE))
  expect_length(neg, 1L)
  expect_identical(
    slope_sign(neg), lm_sign(pen, "bill_length_mm", "bill_depth_mm")
  )
  pos <- fit_line(fsc(
    pen, "flipper_length_mm", "body_mass_g", "t", "x", "y",
    fit = TRUE
  ))
  expect_length(pos, 1L)
  expect_identical(slope_sign(pos), 1)
  expect_identical(slope_sign(neg), -1)
})

test_that("figure_demo draws every module's figure", {
  wine <- utils::read.csv(file.path(
    root, "datasets", "wine-quality", "winequality-red.csv"
  ))
  want <- list(
    "c-m1-v01-ticket" = c(
      "flipper length on bill length",
      "bill length (mm)", "flipper length (mm)"
    ),
    "c-m2-v02-ols" = c(
      "body mass on flipper length",
      "flipper length (mm)", "body mass (g)"
    ),
    "c-m3-v03-red" = c(
      "bill depth on bill length",
      "bill length (mm)", "bill depth (mm)"
    ),
    "c-m3-v04-determinism" = c(
      "body mass on flipper length",
      "flipper length (mm)", "body mass (g)"
    ),
    "c-m4-v02-ingest" = c(
      "Wine quality on alcohol",
      "alcohol (% vol)", "quality score (0-10)"
    )
  )
  withr::with_dir(root, {
    for (id in names(want)) {
      txt <- svg_txt(agenticds:::demo_plot(id))
      expected <- if (grepl("^c-m4", id)) {
        nrow(wine)
      } else {
        nrow(pen) + length(unique(pen$species))
      }
      # Every row is a point; the labels sit on their own axes.
      expect_identical(nrow(circles(txt)), expected, info = id)
      expect_identical(label_of(txt, "title"), want[[id]][1])
      expect_identical(label_of(txt, "xlab"), want[[id]][2])
      expect_identical(label_of(txt, "ylab"), want[[id]][3])
    }
    # The demo writes the same figure through figure_svg.
    d <- tempfile("demo-")
    dir.create(d)
    withr::with_envvar(
      c(ADS_OUT = d), figure_demo("c-m4-v02-ingest")
    )
    expect_true(file.exists(file.path(d, "plot.svg")))
    wp <- circles(svg_txt(agenticds:::demo_plot("c-m4-v02-ingest")))
    expect_gt(rho(wp[, "x"], wine$alcohol), 0.999)
    expect_lt(rho(wp[, "y"], wine$quality), -0.999)
  })
  expect_error(figure_demo("c-m9-v01-x"))
  expect_error(figure_demo("nonsense"))
})
