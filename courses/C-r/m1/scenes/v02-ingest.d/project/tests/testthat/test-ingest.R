library(testthat)
root <- normalizePath(testthat::test_path("..", ".."))
old <- setwd(root)
if (!exists("run_scene")) source("R/ingest.R")
scene_lines <- length(readLines("R/ingest.R"))
scene_wide <- max(nchar(readLines("R/ingest.R")))
out <- utils::capture.output(ok <- run_scene())
txt <- paste(out, collapse = " ")

test_that("the scene file fits the screen, 25 lines, 59 cols", {
  expect_lte(scene_lines, 25L)
  expect_lte(scene_wide, 59L)
})
test_that("the scene reports TRUE with its verdict line", {
  expect_true(ok)
  expect_match(
    txt, "contract: c-m1 ingest 344 -> 342: TRUE",
    fixed = TRUE
  )
})
test_that("the 344 -> 342 drop and the 9 sex NAs are printed", {
  expect_match(txt, "rows 344 -> 342")
  expect_match(txt, "sex still NA in 9 clean rows")
  expect_match(txt, "sex +11")
})
setwd(old)
