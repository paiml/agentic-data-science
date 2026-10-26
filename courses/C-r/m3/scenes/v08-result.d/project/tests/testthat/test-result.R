library(testthat)
root <- normalizePath(testthat::test_path("..", ".."))
old <- setwd(root)
if (!exists("run_scene")) source("R/result.R")
scene_src <- readLines("R/result.R")
scene_lines <- length(scene_src)
setwd(old)
h <- mget(c(
  "run_scene",
  "feats",
  "verdict",
  "load_clean",
  "read_centroids",
  "kmeans_fixed"
), inherits = TRUE)
work <- tempfile("scene")
dir.create(work)
files <- list.files(root, full.names = TRUE)
file.copy(files, work, recursive = TRUE)
old <- setwd(work)
verdict_out <- utils::capture.output(ok <- h$run_scene())
out <- paste(verdict_out, collapse = " ")

test_that("the scene file is 59 columns wide at most", {
  expect_lte(max(nchar(scene_src)), 59L)
})
test_that("the scene file fits the screen, 25 lines or fewer", {
  expect_lte(scene_lines, 25L)
})
test_that("verdict prints a failure as FALSE and returns it", {
  res <- utils::capture.output(r <- h$verdict("x: ", FALSE))
  expect_false(r)
  expect_match(res, "x: FALSE")
})
test_that("sizes are 133, 123 and 86", {
  expect_match(out, "sizes 133 123 86")
})
test_that("the objective is 378.29, the golden objective", {
  expect_match(out, "objective 378.29")
  expect_match(out, "golden 378.29")
})
test_that("the objective agrees within one in a billion", {
  d <- h$load_clean("data/penguins.csv")
  cen <- h$read_centroids("data/centroids.csv")
  km <- h$kmeans_fixed(d, cen)
  g <- jsonlite::fromJSON("data/p3.json")$kmeans
  expect_lt(abs(km$objective - g$objective), 1e-9)
  expect_equal(dim(km$centers), c(3L, 4L))
})
test_that("the scene verdict is TRUE", {
  expect_true(ok)
  expect_match(out, "kmeans matches golden: TRUE")
})
setwd(old)
