library(testthat)
root <- normalizePath(testthat::test_path("..", ".."))
if (!exists("run_scene")) {
  withr::with_dir(root, {
    source("R/helpers.R")
    source("R/repro.R")
  })
}
work <- tempfile("scene")
dir.create(work)
file.copy(dir(root, full.names = TRUE), work, recursive = TRUE)
old <- setwd(work)
verdict_out <- utils::capture.output(ok <- run_scene())
scene <- readLines(file.path(root, "R", "repro.R"))
ticks <- readLines(file.path(root, "..", "ticks.txt"))
out <- paste(verdict_out, collapse = " ")

test_that("the scene file fits the camera: 25 lines, width 59", {
  expect_lte(length(scene), 25L)
  expect_lte(max(nchar(scene)), 59L)
})
test_that("ticks are whole statements found strictly forward", {
  at <- vapply(ticks, function(t) {
    which(grepl(t, scene, fixed = TRUE))[1]
  }, integer(1))
  expect_false(anyNA(at))
  expect_true(all(diff(at) > 0))
})
test_that("wine builds the data path for a colour", {
  expect_equal(wine("red"), "data/winequality-red.csv")
})
test_that("verdict reports a failing oracle as FALSE", {
  txt <- utils::capture.output(res <- verdict(FALSE, "x"))
  expect_false(res)
  expect_match(txt, "contract: c-m4 x: FALSE")
})
test_that("the sort order differs between locales", {
  expect_true(ok)
  expect_match(out, "sort order, C: +2 4 6 3 1 5")
  expect_match(out, "sort order, en_US: +2 3 1 4 5 6")
})
test_that("the pipeline rmse is identical to 17 digits", {
  g <- jsonlite::fromJSON("data/p4.json")
  keys <- c("b1", "A2", "a3", "B4", "c5", "C6")
  a <- locale_run("C", keys)
  b <- locale_run("en_US.UTF-8", keys)
  expect_identical(a$rmse, b$rmse)
  expect_identical(a$test, 1299L)
  expect_equal(a$rmse, g$rmse, tolerance = 1e-12)
  expect_match(out, "order moves, split and rmse do not: TRUE")
})
test_that("the row-index split is unaffected by the locale", {
  w <- agenticds::read_wine(wine("red"), wine("white"))
  is_test <- seq_len(nrow(w)) %% 5L == 0L
  expect_equal(sum(is_test), 1299L)
})
setwd(old)
