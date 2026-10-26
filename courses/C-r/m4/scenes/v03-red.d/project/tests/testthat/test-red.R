library(testthat)
root <- normalizePath(testthat::test_path("..", ".."))
if (!exists("run_scene")) {
  withr::with_dir(root, {
    source("R/helpers.R")
    source("R/red.R")
  })
}
work <- tempfile("scene")
dir.create(work)
file.copy(dir(root, full.names = TRUE), work, recursive = TRUE)
old <- setwd(work)
verdict_out <- utils::capture.output(ok <- run_scene())
scene <- readLines(file.path(root, "R", "red.R"))
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
test_that("the shipped split hits the golden count", {
  expect_true(ok)
  expect_match(out, "golden n_test: 1299")
  expect_match(out, "split_wine:    1299")
})
test_that("the broken 1-in-4 split misses it and is flagged", {
  expect_match(out, "broken \\(1 in 4\\): 1624")
  expect_match(out, "contract: c-m4 bug caught: TRUE")
})
test_that("1-in-4 of 6497 rows is not the golden 1299", {
  expect_equal(sum(seq_len(6497L) %% 4L == 0L), 1624L)
  expect_false(1624L == jsonlite::fromJSON("data/p4.json")$n_test)
})
setwd(old)
