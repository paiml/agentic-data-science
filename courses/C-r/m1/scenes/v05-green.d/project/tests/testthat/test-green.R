library(testthat)
root <- normalizePath(testthat::test_path("..", ".."))
old <- setwd(root)
if (!exists("run_scene")) source("R/green.R")
scene_lines <- length(readLines("R/green.R"))
scene_wide <- max(nchar(readLines("R/green.R")))
out <- utils::capture.output(ok <- run_scene())
txt <- paste(out, collapse = " ")

test_that("the scene file fits the screen, 25 lines, 59 cols", {
  expect_lte(scene_lines, 25L)
  expect_lte(scene_wide, 59L)
})
test_that("the scene reports TRUE with its verdict line", {
  expect_true(ok)
  expect_match(
    txt, "contract: c-m1 p1 tests green: TRUE",
    fixed = TRUE
  )
})
test_that("all six p1 tests pass", {
  expect_match(txt, "passed: 6  failed: 0")
})
setwd(old)
