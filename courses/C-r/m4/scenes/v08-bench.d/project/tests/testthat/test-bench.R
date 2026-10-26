library(testthat)
root <- normalizePath(testthat::test_path("..", ".."))
if (!exists("run_scene")) {
  withr::with_dir(root, {
    source("R/helpers.R")
    source("R/bench.R")
  })
}
work <- tempfile("scene")
dir.create(work)
file.copy(dir(root, full.names = TRUE), work, recursive = TRUE)
old <- setwd(work)
verdict_out <- utils::capture.output(ok <- run_scene())
scene <- readLines(file.path(root, "R", "bench.R"))
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
test_that("both engines print the same per-colour table", {
  expect_true(ok)
  expect_match(out, "red +5.636023 +1599")
  expect_match(out, "white +5.877909 +4898")
  expect_match(out, "dplyr == data.table: TRUE")
})
test_that("timings are shown for both engines but never asserted", {
  expect_match(out, "timings \\(seconds, not asserted\\)")
  expect_match(out, "dplyr")
  expect_match(out, "data.table")
  b <- agenticds::bench_wine(
    agenticds::read_wine(wine("red"), wine("white")),
    reps = 2L
  )
  expect_equal(b$engine, c("dplyr", "data.table"))
  expect_true(all(b$seconds >= 0))
})
test_that("the aggregates match the golden colour means", {
  g <- jsonlite::fromJSON("data/p4.json")
  w <- agenticds::read_wine(wine("red"), wine("white"))
  a <- agenticds::aggregate_dplyr(w)
  expect_equal(a$mean_quality[a$color == "red"],
    g$mean_quality_by_color$red,
    tolerance = 1e-8
  )
  expect_equal(a$n, c(1599L, 4898L))
})
setwd(old)
