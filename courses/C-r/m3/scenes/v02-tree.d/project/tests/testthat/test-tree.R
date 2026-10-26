library(testthat)
root <- normalizePath(testthat::test_path("..", ".."))
old <- setwd(root)
if (!exists("run_scene")) source("R/tree.R")
scene_src <- readLines("R/tree.R")
scene_lines <- length(scene_src)
setwd(old)
h <- mget(c(
  "run_scene",
  "feats",
  "verdict",
  "load_clean",
  "read_split",
  "fit_species_clf",
  "predict_species_clf"
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
test_that("the tree has the golden accuracy, two errors in 85", {
  expect_true(ok)
  expect_match(out, "accuracy 0.9765 errors 2")
  expect_match(out, "tree matches golden: TRUE")
})
test_that("the printed confusion matrix has the golden cells", {
  expect_match(out, "Adelie +37 +0 +0")
  expect_match(out, "Chinstrap +0 +16 +1")
  expect_match(out, "Gentoo +0 +1 +30")
})
test_that("the tree is a rpart classifier with three species", {
  d <- readr::read_csv("data/penguins.csv", show_col_types = FALSE)
  d <- tidyr::drop_na(d, tidyr::all_of(h$feats))
  s <- readr::read_csv("data/split.csv", show_col_types = FALSE)$set
  fit <- h$fit_species_clf(d[s == "train", ])
  expect_s3_class(fit$fit, "rpart")
  pred <- h$predict_species_clf(fit, d[s == "test", ])
  expect_equal(levels(pred), c("Adelie", "Chinstrap", "Gentoo"))
  expect_equal(length(pred), 85L)
})
setwd(old)
