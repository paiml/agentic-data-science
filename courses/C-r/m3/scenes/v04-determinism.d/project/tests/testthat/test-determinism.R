library(testthat)
root <- normalizePath(testthat::test_path("..", ".."))
old <- setwd(root)
if (!exists("run_scene")) source("R/determinism.R")
scene_src <- readLines("R/determinism.R")
scene_lines <- length(scene_src)
setwd(old)
h <- mget(c(
  "run_scene",
  "feats",
  "verdict",
  "load_clean",
  "read_split",
  "read_centroids",
  "fit_species_clf",
  "predict_species_clf",
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
test_that("two runs return identical predictions and k-means", {
  expect_match(out, "same twice: TRUE")
})
test_that("k-means does not move the random seed", {
  expect_match(out, "seed kept: TRUE")
})
test_that("the scene verdict is TRUE", {
  expect_true(ok)
  expect_match(out, "deterministic: TRUE")
})
test_that("a random draw does move the seed (the check can fail)", {
  set.seed(1)
  seed <- .Random.seed
  stats::runif(1)
  expect_false(identical(seed, .Random.seed))
})
test_that("fixtures give 342 rows, 85 test rows, 3 centroids", {
  d <- h$load_clean("data/penguins.csv")
  s <- h$read_split("data/split.csv")
  cen <- h$read_centroids("data/centroids.csv")
  expect_equal(nrow(d), 342L)
  expect_equal(sum(s == "test"), 85L)
  expect_equal(dim(cen), c(3L, 4L))
})
setwd(old)
