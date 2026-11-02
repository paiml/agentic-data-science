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
    rot = grepl("rotate(", el, fixed = TRUE),
    anchor = ifelse(
      grepl("text-anchor='", el, fixed = TRUE),
      sub(".*text-anchor='([a-z]+)'.*", "\\1", el),
      "start"
    )
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
# Gridlines are the only polylines of width 1.75 (major) in #EBEBEB.
gridlines <- function(txt) {
  pl <- grepl("^<polyline ", txt)
  major <- grepl("stroke-width: 1.75", txt, fixed = TRUE)
  grey <- grepl("#EBEBEB", txt, fixed = TRUE)
  g <- txt[pl & major & grey]
  pts <- sub("^<polyline points='([^']*)'.*", "\\1", g)
  m <- do.call(rbind, strsplit(trimws(pts), "[ ,]"))
  storage.mode(m) <- "double"
  m
}
# Value -> pixel maps read only from the drawn tick labels and the
# gridline each one sits on. Fails unless every tick fits one line.
axis_map <- function(txt) {
  t <- texts(txt)
  t <- t[!t$rot & t$y > min(t$y) & t$y < max(t$y), ]
  g <- gridlines(txt)
  xt <- t[t$anchor == "middle", ]
  yt <- t[t$anchor == "end", ]
  gx <- sort(g[g[, 1] == g[, 3], 1])
  gy <- sort(g[g[, 2] == g[, 4], 2])
  xt <- xt[order(xt$x), ]
  yt <- yt[order(yt$y), ]
  stopifnot(
    length(gx) == nrow(xt), length(gy) == nrow(yt),
    max(abs(gx - xt$x)) < 0.05,
    diff(range(yt$y - gy)) < 0.05
  )
  fit1 <- function(v, p) {
    cf <- stats::coef(stats::lm(p ~ v))
    stopifnot(max(abs(cf[[1]] + cf[[2]] * v - p)) < 0.05)
    function(z) cf[[1]] + cf[[2]] * z
  }
  list(
    px = fit1(as.numeric(xt$label), gx),
    py = fit1(as.numeric(yt$label), gy),
    xlab = xt$label, ylab = rev(yt$label)
  )
}
# The fit line: the one polyline of more than two points.
fit_pts <- function(txt) {
  el <- txt[grepl("^<polyline ", txt)]
  pts <- strsplit(trimws(sub(
    "^<polyline points='([^']*)'.*", "\\1", el
  )), " ")
  el <- pts[lengths(pts) > 2L]
  stopifnot(length(el) == 1L)
  m <- do.call(rbind, strsplit(el[[1]], ","))
  storage.mode(m) <- "double"
  m
}
# Every datum lands where its value maps (first n circles are data).
expect_on_axes <- function(txt, x, y, info = "") {
  am <- axis_map(txt)
  xy <- circles(txt)[seq_along(x), , drop = FALSE]
  px_gap_ok(xy[, "x"] - am$px(x), info)
  px_gap_ok(xy[, "y"] - am$py(y), info)
}
# Every pixel gap is under 0.6 px.
px_gap_ok <- function(gap, info) {
  testthat::expect_lt(max(abs(gap)), 0.6, label = info)
}
# The fit's two ends are the least-squares line at the data range.
expect_fit_ends <- function(txt, x, y, info = "") {
  am <- axis_map(txt)
  m <- fit_pts(txt)
  cf <- stats::coef(stats::lm(y ~ x))
  xr <- range(x)
  e <- rbind(m[1, ], m[nrow(m), ])
  want_y <- am$py(cf[[1]] + cf[[2]] * xr)
  px_gap_ok(e[, 1] - am$px(xr), info)
  px_gap_ok(e[, 2] - want_y, info)
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

test_that("ticks come from the data, and values map to pixels", {
  # Known inputs: the tick strings are fixed here, not read from
  # ggplot, and the markers must sit at their value's pixel.
  d <- data.frame(a = c(0, 5, 10), b = c(0, 50, 100))
  txt <- svg_txt(fsc(d, "a", "b", "t", "x", "y"))
  am <- axis_map(txt)
  expect_identical(am$xlab, c("0.0", "2.5", "5.0", "7.5", "10.0"))
  expect_identical(am$ylab, c("0", "25", "50", "75", "100"))
  expect_on_axes(txt, d$a, d$b)
  # Axes are not interchangeable: the y axis maps y, not x.
  expect_gt(abs(am$py(5) - am$py(50)), 100)
  s <- data.frame(a = c(1, 4, 9, 2, 7), b = c(30, 10, 80, 55, 60))
  expect_on_axes(svg_txt(fsc(s, "a", "b", "t", "x", "y")), s$a, s$b)
  # A swapped y vector puts markers off their values.
  txt2 <- svg_txt(fsc(s, "a", "b", "t", "x", "y"))
  am2 <- axis_map(txt2)
  off <- abs(circles(txt2)[, "y"] - am2$py(rev(s$b)))
  expect_gt(max(off), 5)
  # Real data, both axes.
  expect_on_axes(
    svg_txt(bill()), pen$bill_length_mm, pen$bill_depth_mm
  )
})

test_that("a fit is one line from the data's ends on the lm line", {
  d <- data.frame(a = c(0, 5, 10), b = c(0, 50, 100))
  txt <- svg_txt(fsc(d, "a", "b", "t", "x", "y", fit = TRUE))
  expect_fit_ends(txt, d$a, d$b)
  # A 1-point-per-pixel check: rises from lower-left to upper-right.
  m <- fit_pts(txt)
  expect_lt(m[nrow(m), 2], m[1, 2])
  expect_gt(m[nrow(m), 1], m[1, 1])
  nofit <- svg_txt(fsc(d, "a", "b", "t", "x", "y"))
  expect_error(fit_pts(nofit))
  s <- data.frame(a = c(1, 4, 9, 2, 7), b = c(30, 10, 80, 55, 60))
  expect_fit_ends(
    svg_txt(fsc(s, "a", "b", "t", "x", "y", fit = TRUE)), s$a, s$b
  )
  # Falling and rising real data; a wrong line is refused.
  neg <- svg_txt(bill(fit = TRUE))
  expect_fit_ends(neg, pen$bill_length_mm, pen$bill_depth_mm)
  expect_on_axes(neg, pen$bill_length_mm, pen$bill_depth_mm)
  pos <- svg_txt(fsc(
    pen, "flipper_length_mm", "body_mass_g", "t", "x", "y",
    fit = TRUE
  ))
  expect_fit_ends(pos, pen$flipper_length_mm, pen$body_mass_g)
  # The mirrored line (slope flipped) is far from the drawn one.
  am <- axis_map(neg)
  cf <- stats::coef(stats::lm(
    -pen$bill_depth_mm ~ pen$bill_length_mm
  ))
  xmin <- min(pen$bill_length_mm)
  expect_gt(
    abs(fit_pts(neg)[1, 2] - am$py(cf[[1]] + cf[[2]] * xmin)), 50
  )
})

test_that("figure_demo draws every module's figure", {
  wine <- utils::read.csv(file.path(
    root, "datasets", "wine-quality", "winequality-red.csv"
  ))
  want <- list(
    "c-m1-v01-ticket" = c(
      "flipper length on bill length",
      "bill length (mm)", "flipper length (mm)",
      "bill_length_mm", "flipper_length_mm"
    ),
    "c-m2-v02-ols" = c(
      "body mass on flipper length",
      "flipper length (mm)", "body mass (g)",
      "flipper_length_mm", "body_mass_g"
    ),
    "c-m3-v03-red" = c(
      "bill depth on bill length",
      "bill length (mm)", "bill depth (mm)",
      "bill_length_mm", "bill_depth_mm"
    ),
    "c-m3-v04-determinism" = c(
      "body mass on flipper length",
      "flipper length (mm)", "body mass (g)",
      "flipper_length_mm", "body_mass_g"
    ),
    "c-m4-v02-ingest" = c(
      "Wine quality on alcohol",
      "alcohol (% vol)", "quality score (0-10)",
      "alcohol", "quality"
    )
  )
  withr::with_dir(root, {
    for (id in names(want)) {
      txt <- svg_txt(agenticds:::demo_plot(id))
      m4 <- grepl("^c-m4", id)
      d <- if (m4) wine else pen
      expected <- if (m4) {
        nrow(wine)
      } else {
        nrow(pen) + length(unique(pen$species))
      }
      # Every row is a point; the labels sit on their own axes.
      expect_identical(nrow(circles(txt)), expected, info = id)
      expect_identical(label_of(txt, "title"), want[[id]][1])
      expect_identical(label_of(txt, "xlab"), want[[id]][2])
      expect_identical(label_of(txt, "ylab"), want[[id]][3])
      x <- d[[want[[id]][4]]]
      y <- d[[want[[id]][5]]]
      # Position and rank: each marker at its value's pixel.
      expect_on_axes(txt, x, y, info = id)
      xy <- circles(txt)[seq_along(x), ]
      expect_gt(rho(xy[, "x"], x), 0.999)
      expect_lt(rho(xy[, "y"], y), -0.999)
      # Module 2 and 4 carry the fit; 1 and 3 carry none.
      if (m4 || grepl("^c-m2", id)) {
        expect_fit_ends(txt, x, y, info = id)
      } else {
        expect_error(fit_pts(txt))
      }
    }
    # The demo writes the same figure through figure_svg.
    d <- tempfile("demo-")
    dir.create(d)
    withr::with_envvar(
      c(ADS_OUT = d), figure_demo("c-m4-v02-ingest")
    )
    expect_true(file.exists(file.path(d, "plot.svg")))
  })
  expect_error(figure_demo("c-m9-v01-x"))
  expect_error(figure_demo("nonsense"))
})
