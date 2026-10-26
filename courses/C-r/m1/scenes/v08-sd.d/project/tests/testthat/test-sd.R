library(testthat)
root <- normalizePath(testthat::test_path("..", ".."))
old <- setwd(root)
if (!exists("run_scene")) source("R/sd.R")
scene_lines <- length(readLines("R/sd.R"))
scene_wide <- max(nchar(readLines("R/sd.R")))
out <- utils::capture.output(ok <- run_scene())
txt <- paste(out, collapse = " ")

test_that("the scene file fits the screen, 25 lines, 59 cols", {
  expect_lte(scene_lines, 25L)
  expect_lte(scene_wide, 59L)
})
test_that("the scene reports TRUE with its verdict line", {
  expect_true(ok)
  expect_match(
    txt, "contract: c-m1 population sd caught: TRUE",
    fixed = TRUE
  )
})
test_that("the population sd fails two checks", {
  expect_match(txt, "sample sd passed 6 failed 0")
  expect_match(txt, "pop sd    passed 4 failed 2")
  expect_match(txt, "summarise gives n, mean and sample sd")
})
setwd(old)
