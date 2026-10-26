library(testthat)
root <- normalizePath(testthat::test_path("..", ".."))
old <- setwd(root)
if (!exists("run_scene")) source("R/red.R")
scene_src <- readLines("R/red.R")
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
test_that("golden is 0.9765 and the planted bug gives 0.0235", {
  expect_match(out, "golden 0.9765 broken 0.0235")
})
test_that("all.equal reports the mean relative difference 40.5", {
  expect_match(out, "Mean relative difference: 40.5")
})
test_that("the bug caught, so the verdict is TRUE", {
  expect_true(ok)
  expect_match(out, "bug caught: TRUE")
})
test_that("the planted bug is not equal to the golden accuracy", {
  d <- h$load_clean("data/penguins.csv")
  s <- h$read_split("data/split.csv")
  pred <- h$predict_species_clf(
    h$fit_species_clf(d[s == "train", ]), d[s == "test", ]
  )
  truth <- factor(d$species[s == "test"], levels = levels(pred))
  expect_equal(mean(truth == pred) + mean(truth != pred), 1)
  expect_gt(abs(mean(truth != pred) - 0.9765), 0.9)
})
setwd(old)
