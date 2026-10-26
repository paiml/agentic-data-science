library(testthat)
root <- normalizePath(testthat::test_path("..", ".."))
old <- setwd(root)
if (!exists("run_scene")) source("R/red.R")
scene_lines <- length(readLines("R/red.R"))
scene_wide <- max(nchar(readLines("R/red.R")))
out <- utils::capture.output(ok <- run_scene())
txt <- paste(out, collapse = " ")

test_that("the scene file fits the screen, 25 lines, 59 cols", {
  expect_lte(scene_lines, 25L)
  expect_lte(scene_wide, 59L)
})
test_that("the scene reports TRUE with its verdict line", {
  expect_true(ok)
  expect_match(
    txt, "contract: c-m1 no-op NA policy caught: TRUE",
    fixed = TRUE
  )
})
test_that("no-op policy fails three checks, the real policy none", {
  expect_match(txt, "real  passed 6 failed 0")
  expect_match(txt, "no-op passed 3 failed 3")
})
setwd(old)
