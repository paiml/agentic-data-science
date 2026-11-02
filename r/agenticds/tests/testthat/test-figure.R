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
  agenticds::figure_svg(p, f)
  readLines(f)
}
# Data points are the round-capped filled paths.
pt_pat <- "fill-rule:nonzero;fill:rgb.*stroke-linecap:round"
n_points <- function(txt) sum(grepl(pt_pat, txt))
point_xy <- function(txt) {
  rx <- ".* d=\"M ([0-9.]+) ([0-9.]+) .*"
  d <- sub(rx, "\\1 \\2", txt[grepl(pt_pat, txt)])
  m <- do.call(rbind, strsplit(d, " "))
  storage.mode(m) <- "double"
  m
}
# The cairo device draws text as glyph shapes, one <use> per
# character, so a text run is read back by looking each glyph's
# outline up in a table made from a known alphabet.
alphabet <- paste0(
  paste(c(letters, LETTERS, 0:9), collapse = ""), " ()-./%,"
)
glyph_paths <- function(txt) {
  s <- grep("<symbol", txt, fixed = TRUE)
  ids <- sub(".*id=\"([^\"]+)\".*", "\\1", txt[s])
  d <- sub(".* d=\"([^\"]*)\".*", "\\1", txt[s + 1L])
  stats::setNames(d, ids)
}
text_runs <- function(txt) {
  paths <- glyph_paths(txt)
  starts <- grep("^<g style=\"fill:rgb", txt)
  lapply(starts, function(s) {
    e <- s + match("</g>", txt[-seq_len(s)])
    u <- txt[s:e][grepl("<use", txt[s:e], fixed = TRUE)]
    id <- sub(".*href=\"#([^\"]+)\".*", "\\1", u)
    xy <- function(a) {
      as.numeric(sub(paste0(".* ", a, "=\"([^\"]+)\".*"), "\\1", u))
    }
    list(
      ink = sub(".*fill:rgb\\(([0-9.]+)%.*", "\\1", txt[s]),
      x = xy("x")[1], y = xy("y")[1], d = unname(paths[id])
    )
  })
}
role <- function(r) {
  if (startsWith(r$ink, "30.19")) {
    "tick"
  } else if (r$y < 50) {
    "title"
  } else if (r$y > 690) {
    "xlab"
  } else if (r$x < 50) {
    "ylab"
  } else {
    "other"
  }
}
runs_by_role <- function(txt) {
  r <- text_runs(txt)
  split(r, vapply(r, role, ""))
}
font_table <- local({
  cache <- new.env()
  function() {
    if (is.null(cache$tab)) {
      ch <- strsplit(alphabet, "")[[1]]
      pieces <- split(ch, (seq_along(ch) - 1L) %/% 18L)
      cache$tab <- stats::setNames(lapply(
        c("title", "xlab", "ylab"), function(k) {
          out <- character()
          for (pc in pieces) {
            s <- paste(pc, collapse = "")
            txt <- svg_lines(fsc(
              pen, "bill_length_mm", "bill_depth_mm", s, s, s
            ))
            d <- runs_by_role(txt)[[k]][[1]]$d
            stopifnot(length(d) == length(pc))
            out <- c(out, stats::setNames(pc, d))
          }
          # The font fuses these pairs into one glyph.
          for (lg in c("fl", "fi", "ff")) {
            txt <- svg_lines(fsc(
              pen, "bill_length_mm", "bill_depth_mm", lg, lg, lg
            ))
            d <- runs_by_role(txt)[[k]][[1]]$d
            if (length(d) == 1L) {
              out <- c(out, stats::setNames(lg, d))
            }
          }
          out
        }
      ), c("title", "xlab", "ylab"))
    }
    cache$tab
  }
})
read_label <- function(txt, k) {
  r <- runs_by_role(txt)[[k]]
  stopifnot(length(r) == 1L)
  tab <- font_table()[[k]]
  paste(unname(tab)[match(r[[1]]$d, names(tab))], collapse = "")
}
ticks_of <- function(p) {
  pp <- ggplot2::ggplot_build(p)$layout$panel_params[[1]]
  list(x = pp$x$get_labels(), y = pp$y$get_labels())
}

test_that("the svg draws one point per row, inside the panel", {
  expect_identical(n_points(svg_lines(bill())), nrow(pen))
  # Grouped: one legend key per species as well.
  g <- svg_lines(bill(group = "species"))
  expect_identical(
    n_points(g), nrow(pen) + length(unique(pen$species))
  )
  expect_identical(n_points(svg_lines(bill(pen[1:5, ]))), 5L)
  xy <- point_xy(svg_lines(bill()))
  expect_true(all(xy[, 1] > 60 & xy[, 1] < 1280))
  expect_true(all(xy[, 2] > 30 & xy[, 2] < 690))
  # Spread over the frame, not collapsed to a point or a line.
  expect_gt(diff(range(xy[, 1])), 0.2 * 1280)
  expect_gt(diff(range(xy[, 2])), 0.2 * 720)
})

test_that("the title and each axis label read back exactly", {
  txt <- svg_lines(fsc(
    pen, "bill_length_mm", "bill_depth_mm",
    "Bill depth on length", "length (mm)", "depth (mm)"
  ))
  expect_identical(read_label(txt, "title"), "Bill depth on length")
  expect_identical(read_label(txt, "xlab"), "length (mm)")
  expect_identical(read_label(txt, "ylab"), "depth (mm)")
  # Swapped labels are caught: each lands on its own axis.
  sw <- svg_lines(fsc(
    pen, "bill_length_mm", "bill_depth_mm",
    "t", "depth (mm)", "length (mm)"
  ))
  expect_identical(read_label(sw, "xlab"), "depth (mm)")
  expect_identical(read_label(sw, "ylab"), "length (mm)")
})

test_that("the svg draws exactly the tick labels of both axes", {
  p <- bill()
  tk <- ticks_of(p)
  rr <- runs_by_role(svg_lines(p))
  got <- vapply(rr$tick, function(r) length(r$d), 0L)
  want <- nchar(c(tk$x, tk$y)[!is.na(c(tk$x, tk$y))])
  expect_gt(length(tk$x), 1L)
  expect_gt(length(tk$y), 1L)
  expect_identical(sort(got), sort(unname(want)))
})

test_that("a fit adds exactly one line and no points", {
  red <- function(p) {
    sum(grepl("stroke:rgb(75.29", svg_lines(p), fixed = TRUE))
  }
  expect_identical(red(bill()), 0L)
  expect_identical(red(bill(fit = TRUE)), 1L)
  expect_identical(
    n_points(svg_lines(bill(fit = TRUE))),
    n_points(svg_lines(bill()))
  )
})

test_that("figure_demo draws every module's figure", {
  d <- tempfile("demo-")
  dir.create(d)
  wine <- nrow(utils::read.csv(file.path(
    root, "datasets", "wine-quality", "winequality-red.csv"
  )))
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
  withr::with_dir(root, withr::with_envvar(c(ADS_OUT = d), {
    for (id in names(want)) {
      unlink(file.path(d, "plot.svg"))
      figure_demo(id)
      txt <- readLines(file.path(d, "plot.svg"))
      expected <- if (grepl("^c-m4", id)) {
        wine
      } else {
        nrow(pen) + length(unique(pen$species))
      }
      # Every row is a point; the labels sit on their own axes.
      expect_identical(n_points(txt), expected, info = id)
      expect_identical(read_label(txt, "title"), want[[id]][1])
      expect_identical(read_label(txt, "xlab"), want[[id]][2])
      expect_identical(read_label(txt, "ylab"), want[[id]][3])
    }
  }))
  expect_error(figure_demo("c-m9-v01-x"))
  expect_error(figure_demo("nonsense"))
})
