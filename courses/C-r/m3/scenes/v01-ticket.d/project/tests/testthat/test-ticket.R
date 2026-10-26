library(testthat)
root <- normalizePath(testthat::test_path("..", ".."))
old <- setwd(root)
if (!exists("run_scene")) source("R/ticket.R")
scene_src <- readLines("R/ticket.R")
scene_lines <- length(scene_src)
setwd(old)
h <- mget(c(
  "run_scene",
  "feats",
  "verdict",
  "load_clean"
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
test_that("the golden confusion is 83 of 85 (0.9765)", {
  g <- jsonlite::fromJSON("data/p3.json")
  expect_equal(sum(diag(g$confusion)), 83L)
  expect_equal(sum(g$confusion), 85L)
  expect_lt(abs(g$accuracy - 83 / 85), 0.005)
})
test_that("the golden cluster sizes are 133, 123, 86", {
  g <- jsonlite::fromJSON("data/p3.json")
  expect_equal(g$kmeans$cluster_sizes, c(133L, 123L, 86L))
})
test_that("the cleaned penguins have 342 rows", {
  d <- h$load_clean("data/penguins.csv")
  expect_equal(nrow(d), 342L)
})
test_that("the scene prints the numbers and a TRUE h$verdict", {
  expect_true(ok)
  expect_match(out, "accuracy 0.9765 = 83 of 85")
  expect_match(out, "cluster sizes 133 123 86")
  expect_match(out, "rows 342")
  expect_match(out, "matches golden: TRUE")
})
setwd(old)
