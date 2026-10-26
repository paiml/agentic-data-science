library(testthat)
root <- normalizePath(testthat::test_path("..", ".."))
old <- setwd(root)
if (!exists("run_scene")) source("R/green.R")
scene_src <- readLines("R/green.R")
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
test_that("the p3 tests pass: 18 passed, none failed, no errors", {
  expect_match(out, "passed 18 failed 0 errors 0")
})
test_that("the scene verdict is TRUE", {
  expect_true(ok)
  expect_match(out, "p3 tests green: TRUE")
})
test_that("helpers load the fixtures and run k-means directly", {
  d <- h$load_clean("data/penguins.csv")
  cen <- h$read_centroids("data/centroids.csv")
  s <- h$read_split("data/split.csv")
  expect_equal(nrow(d), 342L)
  km <- h$kmeans_fixed(d, cen)
  expect_equal(tabulate(km$cluster, nbins = 3), c(133L, 123L, 86L))
  fit <- h$fit_species_clf(d[s == "train", ])
  pred <- h$predict_species_clf(fit, d[s == "test", ])
  expect_equal(length(pred), 85L)
})
test_that("a failing expectation turns the green check red", {
  bad <- tempfile("bad")
  dir.create(bad)
  code <- 'test_that("x", expect_equal(1, 2))'
  writeLines(code, file.path(bad, "test-x.R"))
  r <- as.data.frame(testthat::test_dir(
    bad,
    reporter = "silent", stop_on_failure = FALSE
  ))
  expect_gt(sum(r$failed), 0L)
})
setwd(old)
