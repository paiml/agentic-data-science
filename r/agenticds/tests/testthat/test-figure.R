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

test_that("figure_demo draws every module's figure", {
  d <- tempfile("demo-")
  dir.create(d)
  ids <- c(
    "c-m1-v01-ticket", "c-m2-v02-ols", "c-m3-v03-red",
    "c-m3-v04-determinism", "c-m4-v02-ingest"
  )
  withr::with_dir(root, withr::with_envvar(c(ADS_OUT = d), {
    for (id in ids) {
      unlink(file.path(d, "plot.svg"))
      figure_demo(id)
      expect_gt(file.size(file.path(d, "plot.svg")), 1000)
    }
  }))
  expect_error(figure_demo("c-m9-v01-x"))
  expect_error(figure_demo("nonsense"))
})
