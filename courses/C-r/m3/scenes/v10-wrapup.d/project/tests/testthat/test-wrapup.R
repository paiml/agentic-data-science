library(testthat)
root <- normalizePath(testthat::test_path("..", ".."))
old <- setwd(root)
if (!exists("run_scene")) source("R/wrapup.R")
scene_src <- readLines("R/wrapup.R")
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
test_that("both contracts hold: tree and kmeans are TRUE", {
  expect_match(out, "tree +kmeans")
  expect_match(out, "TRUE +TRUE")
})
test_that("the scene verdict is TRUE", {
  expect_true(ok)
  expect_match(out, "wrap-up all OK: TRUE")
})
test_that("the tree accuracy and k-means objective are golden", {
  d <- h$load_clean("data/penguins.csv")
  s <- h$read_split("data/split.csv")
  g <- jsonlite::fromJSON("data/p3.json")
  fit <- h$fit_species_clf(d[s == "train", ])
  pred <- h$predict_species_clf(fit, d[s == "test", ])
  acc <- mean(d$species[s == "test"] == pred)
  expect_lt(abs(acc - g$accuracy), 0.005)
  km <- h$kmeans_fixed(d, h$read_centroids("data/centroids.csv"))
  expect_lt(abs(km$objective - g$kmeans$objective), 1e-6)
})
setwd(old)
