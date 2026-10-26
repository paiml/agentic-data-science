library(testthat)
root <- normalizePath(testthat::test_path("..", ".."))
if (!exists("run_scene")) {
  withr::with_dir(root, {
    source("R/helpers.R")
    source("R/ticket.R")
  })
}
work <- tempfile("scene")
dir.create(work)
file.copy(file.path(root, "data"), work, recursive = TRUE)
old <- setwd(work)
verdict_out <- utils::capture.output(ok <- run_scene())
scene <- readLines(file.path(root, "R", "ticket.R"))
ticks <- readLines(file.path(root, "..", "ticks.txt"))

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
test_that("the data checksums verify, a changed byte fails", {
  expect_true(check_sums("data"))
  bad <- tempfile("bad")
  dir.create(bad)
  file.copy(list.files("data", full.names = TRUE), bad)
  red <- file.path(bad, "winequality-red.csv")
  cat("x", file = red, append = TRUE)
  expect_false(check_sums(bad))
})
test_that("the golden ticket is the 6497-row 1-in-5 split", {
  g <- jsonlite::fromJSON("data/p4.json")
  expect_equal(g$n_rows, 6497L)
  expect_equal(g$n_test, 1299L)
  expect_equal(g$n_train, 5198L)
  expect_equal(g$rmse, 0.7602516, tolerance = 1e-6)
  expect_equal(g$r2, 0.2598545, tolerance = 1e-6)
})
test_that("the scene prints golden fields and a green verdict", {
  out <- paste(verdict_out, collapse = " ")
  expect_true(ok)
  expect_match(out, "n_rows")
  expect_match(out, "ticket oracle holds for 6497 rows: TRUE")
})
test_that("verdict reports a failing oracle as FALSE", {
  out <- utils::capture.output(res <- verdict(FALSE, "x"))
  expect_false(res)
  expect_match(out, "contract: c-m4 x: FALSE")
})
test_that("wine builds the data path for a colour", {
  expect_equal(wine("red"), "data/winequality-red.csv")
})
setwd(old)
