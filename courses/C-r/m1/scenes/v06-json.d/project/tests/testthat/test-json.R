library(testthat)
root <- normalizePath(testthat::test_path("..", ".."))
old <- setwd(root)
if (!exists("run_scene")) source("R/json.R")
scene_lines <- length(readLines("R/json.R"))
scene_wide <- max(nchar(readLines("R/json.R")))
out <- utils::capture.output(ok <- run_scene())
txt <- paste(out, collapse = " ")

test_that("the scene file fits the screen, 25 lines, 59 cols", {
  expect_lte(scene_lines, 25L)
  expect_lte(scene_wide, 59L)
})
test_that("the scene reports TRUE with its verdict line", {
  expect_true(ok)
  expect_match(
    txt, "contract: c-m1 profile JSON equals the golden: TRUE",
    fixed = TRUE
  )
})
test_that("the JSON carries the golden counts", {
  expect_match(txt, "\"n\": 151")
  expect_match(txt, "\"n\": 123")
  expect_match(txt, "largest gap to golden/p1.json")
})
setwd(old)
