library(testthat)
root <- normalizePath(testthat::test_path("..", ".."))
old <- setwd(root)
if (!exists("run_scene")) source("R/gates.R")
scene_lines <- length(readLines("R/gates.R"))
scene_wide <- max(nchar(readLines("R/gates.R")))
out <- utils::capture.output(ok <- run_scene())
txt <- paste(out, collapse = " ")

test_that("the scene file fits the screen, 25 lines, 59 cols", {
  expect_lte(scene_lines, 25L)
  expect_lte(scene_wide, 59L)
})
test_that("the scene reports TRUE with its verdict line", {
  expect_true(ok)
  expect_match(
    txt, "contract: c-m1 gates green: TRUE",
    fixed = TRUE
  )
})
test_that("every gate prints its count", {
  expect_match(txt, "over 68 cols: 0  tabs: 0")
  expect_match(txt, "p1 tests passed 6 of 6")
})
setwd(old)
