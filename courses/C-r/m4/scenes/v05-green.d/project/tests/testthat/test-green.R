library(testthat)
root <- normalizePath(testthat::test_path("..", ".."))
if (!exists("run_scene")) {
  withr::with_dir(root, {
    source("R/helpers.R")
    source("R/green.R")
  })
}
work <- tempfile("scene")
dir.create(work)
file.copy(dir(root, full.names = TRUE), work, recursive = TRUE)
old <- setwd(work)
verdict_out <- utils::capture.output(ok <- run_scene())
scene <- readLines(file.path(root, "R", "green.R"))
ticks <- readLines(file.path(root, "..", "ticks.txt"))
out <- paste(verdict_out, collapse = " ")

test_that("the scene file fits the camera: 25 lines, width 59", {
  expect_lte(length(scene), 25L)
  expect_lte(max(nchar(scene)), 59L)
})
test_that("ticks are whole statements found strictly forward", {
  at <- vapply(ticks, function(t) {
    which(grepl(t, scene, fixed = TRUE))[1]
  }, integer(1))
  expect_false(anyNA(at))
  expect_true(all(diff(at) > 0))
})
test_that("wine builds the data path for a colour", {
  expect_equal(wine("red"), "data/winequality-red.csv")
})
test_that("verdict reports a failing oracle as FALSE", {
  txt <- utils::capture.output(res <- verdict(FALSE, "x"))
  expect_false(res)
  expect_match(txt, "contract: c-m4 x: FALSE")
})
test_that("the scene shows four green PASS lines and a verdict", {
  expect_true(ok)
  for (nm in c("rows", "split", "rmse", "r2")) {
    expect_match(out, paste("PASS", nm))
  }
  expect_false(grepl("FAIL", out))
  expect_match(out, "all four checks pass: TRUE")
})
test_that("report prints FAIL and returns FALSE on a red check", {
  chk <- list(a = TRUE, b = FALSE)
  txt <- utils::capture.output(res <- report(chk))
  expect_false(res)
  expect_match(txt[1], "PASS a")
  expect_match(txt[2], "FAIL b")
})
setwd(old)
