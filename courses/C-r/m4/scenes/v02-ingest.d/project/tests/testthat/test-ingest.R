library(testthat)
root <- normalizePath(testthat::test_path("..", ".."))
if (!exists("run_scene")) {
  withr::with_dir(root, {
    source("R/helpers.R")
    source("R/ingest.R")
  })
}
work <- tempfile("scene")
dir.create(work)
file.copy(dir(root, full.names = TRUE), work, recursive = TRUE)
old <- setwd(work)
verdict_out <- utils::capture.output(ok <- run_scene())
scene <- readLines(file.path(root, "R", "ingest.R"))
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
test_that("the scene counts 1599 red and 4898 white rows", {
  expect_true(ok)
  expect_match(out, "1599")
  expect_match(out, "4898")
  expect_match(out, "contract: c-m4 6497 rows: TRUE")
})
test_that("read_wine binds both colours into 6497 rows", {
  w <- agenticds::read_wine(wine("red"), wine("white"))
  g <- jsonlite::fromJSON("data/p4.json")
  expect_equal(nrow(w), g$n_rows)
  expect_equal(as.vector(table(w$color)), c(1599L, 4898L))
})
setwd(old)
