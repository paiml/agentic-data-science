library(testthat)
root <- normalizePath(testthat::test_path("..", ".."))
old <- setwd(root)
if (!exists("run_scene")) source("R/profile.R")
scene_lines <- length(readLines("R/profile.R"))
scene_wide <- max(nchar(readLines("R/profile.R")))
out <- utils::capture.output(ok <- run_scene())
txt <- paste(out, collapse = " ")

test_that("the scene file fits the screen, 25 lines, 59 cols", {
  expect_lte(scene_lines, 25L)
  expect_lte(scene_wide, 59L)
})
test_that("the scene reports TRUE with its verdict line", {
  expect_true(ok)
  expect_match(
    txt, "contract: c-m1 151/68/123, sd n-1: TRUE",
    fixed = TRUE
  )
})
test_that("the sample sd is printed next to the population sd", {
  expect_match(txt, "n-1 by hand 504.1162")
  expect_match(txt, "n \\(population\\) 502.0628")
  expect_match(txt, "Gentoo 123")
})
setwd(old)
