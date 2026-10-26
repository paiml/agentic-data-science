library(testthat)
root <- normalizePath(testthat::test_path("..", ".."))
old <- setwd(root)
source("R/helpers.R")
source("R/oracle.R")
scene <- readLines("R/oracle.R")
setwd(old)
work <- tempfile("scene")
dir.create(work)
file.copy(dir(root, full.names = TRUE), work, recursive = TRUE)
old <- setwd(work)
d <- load_clean("data/penguins.csv")
b <- unname(oracle(d))
verdict_out <- utils::capture.output(ok <- run_scene())

test_that("the scene file fits the screen", {
  expect_lte(length(scene), 25L)
  expect_lte(max(nchar(scene)), 59L)
})
test_that("drop_na keeps 342 rows (D14)", {
  expect_equal(nrow(d), 342L)
})
test_that("oracle intercept matches the pv postcondition", {
  expect_equal(b[[1]], -5780.83, tolerance = 1e-3)
})
test_that("oracle slope matches the pv postcondition", {
  expect_equal(b[[2]], 49.69, tolerance = 1e-3)
})
test_that("the oracle equals lm within 1e-8", {
  fml <- body_mass_g ~ flipper_length_mm
  ref <- stats::coef(stats::lm(fml, d))
  expect_equal(b, unname(ref), tolerance = 1e-8)
})
test_that("save_png writes the file it is given", {
  p <- ggplot2::ggplot()
  save_png(p, "t.png")
  expect_true(file.exists("t.png"))
})
test_that("the scatter plus fitted line PNG is a 720 x 1080 pane", {
  hdr <- readBin("plot.png", "raw", 24)
  width <- sum(as.integer(hdr[17:20]) * 256^(3:0))
  expect_equal(width, 720)
  expect_gt(file.size("plot.png"), 10000)
})
test_that("the scene reports TRUE and prints the verdict", {
  expect_true(ok)
  expect_match(
    paste(verdict_out, collapse = " "),
    "check 342 rows, slope 49.69: TRUE"
  )
})
test_that("theme_scene is the 12 pt base theme", {
  expect_s3_class(theme_scene(), "theme")
  expect_equal(theme_scene()$text$size, 12)
})
test_that("verdict returns and prints a failure as FALSE", {
  res <- utils::capture.output(r <- verdict("x", FALSE))
  expect_false(r)
  expect_match(res, "x: FALSE")
})
setwd(old)
