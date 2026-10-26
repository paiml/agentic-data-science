library(testthat)
root <- normalizePath(testthat::test_path("..", ".."))
if (!exists("run_scene")) {
  withr::with_dir(root, {
    source("R/helpers.R")
    source("R/pipeline.R")
  })
}
work <- tempfile("scene")
dir.create(work)
file.copy(dir(root, full.names = TRUE), work, recursive = TRUE)
old <- setwd(work)
verdict_out <- utils::capture.output(ok <- run_scene())
scene <- readLines(file.path(root, "R", "pipeline.R"))
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
test_that("the scene prints split sizes and rmse, verdict TRUE", {
  expect_true(ok)
  expect_match(out, "rows: 6497 +train: 5198 +test: 1299")
  expect_match(out, "rmse: 0.760252 +r2: +0.259854")
  expect_match(out, "pipeline matches the golden ticket: TRUE")
})
test_that("pipeline_wine reproduces the golden rmse and r2", {
  g <- jsonlite::fromJSON("data/p4.json")
  res <- agenticds::pipeline_wine(wine("red"), wine("white"))
  expect_equal(res$rmse, g$rmse, tolerance = 1e-6)
  expect_equal(res$r2, g$r2, tolerance = 1e-6)
  expect_equal(res$n_train + res$n_test, res$n_rows)
})
setwd(old)
