library(testthat)
old_collate <- Sys.getlocale("LC_COLLATE")
root <- normalizePath(testthat::test_path("..", ".."))
old <- setwd(root)
if (!exists("run_scene")) source("R/locale.R")
scene_src <- readLines("R/locale.R")
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
test_that("sorting differs: C capitals first, en_US interleaved", {
  expect_match(out, "C A B a b")
  expect_match(out, "en_US.UTF-8 a A b B")
})
test_that("accuracy is 0.97647059 in both locales", {
  expect_match(out, "A B a b 0.97647059")
  expect_match(out, "a A b B 0.97647059")
})
test_that("the scene verdict is TRUE", {
  expect_true(ok)
  expect_match(out, "locale ok: TRUE")
})
test_that("the scene restores the original collation", {
  expect_equal(Sys.getlocale("LC_COLLATE"), old_collate)
})
setwd(old)
