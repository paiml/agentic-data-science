root <- Sys.getenv(
  "ADS_ROOT",
  unset = normalizePath(file.path("..", "..", "..", ".."))
)
csv <- file.path(root, "data", "anscombe.csv")

test_that("the data file matches its pinned sha256", {
  sums <- readLines(file.path(root, "data", "SHA256SUMS"))
  pin <- sums[grepl("anscombe.csv$", sums)]
  expect_length(pin, 1L)
  got <- system2("sha256sum", csv, stdout = TRUE)
  expect_identical(
    strsplit(got, " ")[[1]][[1]], strsplit(pin, " ")[[1]][[1]]
  )
})

test_that("read gives 44 rows in four sets", {
  d <- anscombe_read(csv)
  expect_identical(dim(d), c(44L, 3L))
  expect_identical(unique(d$set), c("I", "II", "III", "IV"))
})

test_that("read refuses a short file", {
  bad <- withr::local_tempfile(fileext = ".csv")
  writeLines(readLines(csv)[1:10], bad)
  expect_error(anscombe_read(bad))
})

test_that("the four sets share their summary statistics", {
  s <- anscombe_summary(anscombe_read(csv))
  expect_equal(s$mean_x, rep(9, 4))
  expect_equal(s$mean_y, rep(7.5, 4), tolerance = 1e-3)
  expect_equal(s$var_x, rep(11, 4))
  expect_equal(s$cor, rep(0.816, 4), tolerance = 1e-3)
  expect_equal(s$slope, rep(0.5, 4), tolerance = 2e-3)
  expect_equal(s$intercept, rep(3, 4), tolerance = 3e-3)
})

test_that("lines are fixed-decimal and one per set", {
  s <- anscombe_summary(anscombe_read(csv))
  out <- anscombe_lines(s)
  expect_length(out, 5L)
  expect_identical(
    out[[2]],
    "I: 11 9.000 7.501 11.000 4.127 0.816 0.500 3.000"
  )
  expect_match(anscombe_lines(s, 1L)[[3]], "^II: 11 9.0 7.5 ")
})

test_that("the plot has four panels and writes an SVG", {
  d <- anscombe_read(csv)
  p <- anscombe_plot(d)
  expect_s3_class(p, "ggplot")
  f <- withr::local_tempfile(fileext = ".svg")
  expect_identical(anscombe_svg(d, f), f)
  txt <- paste(readLines(f), collapse = "\n")
  expect_match(txt, "^<\\?xml")
  expect_match(txt, "</svg>")
})

test_that("the same data gives byte-identical SVG twice", {
  d <- anscombe_read(csv)
  a <- withr::local_tempfile(fileext = ".svg")
  b <- withr::local_tempfile(fileext = ".svg")
  anscombe_svg(d, a)
  anscombe_svg(d, b)
  expect_identical(readLines(a), readLines(b))
})
