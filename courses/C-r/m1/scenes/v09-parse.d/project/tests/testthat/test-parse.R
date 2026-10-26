library(testthat)
root <- normalizePath(testthat::test_path("..", ".."))
old <- setwd(root)
if (!exists("run_scene")) source("R/parse.R")
scene_lines <- length(readLines("R/parse.R"))
scene_wide <- max(nchar(readLines("R/parse.R")))
out <- utils::capture.output(ok <- run_scene())
txt <- paste(out, collapse = " ")

test_that("the scene file fits the screen, 25 lines, 59 cols", {
  expect_lte(scene_lines, 25L)
  expect_lte(scene_wide, 59L)
})
test_that("the scene reports TRUE with its verdict line", {
  expect_true(ok)
  expect_match(
    txt, "contract: c-m1 bad number reported: TRUE",
    fixed = TRUE
  )
})
test_that("the bad cell is reported by row with its text", {
  expect_match(txt, "a double")
  expect_match(txt, "heavy")
})
test_that("the report is exact: row 2 only", {
  expect_match(txt, "2 a double heavy")
})
setwd(old)
