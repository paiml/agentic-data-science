library(testthat)
root <- normalizePath(testthat::test_path("..", ".."))
old <- setwd(root)
if (!exists("run_scene")) source("R/mutation.R")
scene_src <- readLines("R/mutation.R")
scene_lines <- length(scene_src)
setwd(old)
h <- mget(c(
  "run_scene",
  "feats",
  "verdict",
  "load_clean",
  "read_centroids",
  "kmeans_fixed",
  "fn_source",
  "mutant"
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
test_that("both mutants die, each by a different objective", {
  expect_match(out, "no_square double_scale")
  expect_match(out, "TRUE +TRUE")
})
test_that("the scene verdict is TRUE", {
  expect_true(ok)
  expect_match(out, "both mutants die: TRUE")
})
test_that("each mutation really changes the source", {
  src <- h$fn_source(h$kmeans_fixed)
  expect_match(src, ")^2)", fixed = TRUE)
  expect_match(src, "scale = spread", fixed = TRUE)
  m <- h$mutant(src, ")^2)", "))")
  expect_false(identical(deparse(m), deparse(h$kmeans_fixed)))
})
test_that("an identity mutant is not killed (the check can pass)", {
  d <- h$load_clean("data/penguins.csv")
  cen <- h$read_centroids("data/centroids.csv")
  km <- h$kmeans_fixed(d, cen)
  g <- jsonlite::fromJSON("data/p3.json")
  expect_lt(abs(km$objective - g$kmeans$objective), 1e-6)
  src <- h$fn_source(h$kmeans_fixed)
  same <- h$mutant(src, "max_iter", "max_iter")
  expect_lt(abs(same(d, cen)$objective - g$kmeans$objective), 1e-6)
})
setwd(old)
