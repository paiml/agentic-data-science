library(testthat)
root <- normalizePath(testthat::test_path("..", ".."))
if (!exists("run_scene")) {
  withr::with_dir(root, {
    source("R/helpers.R")
    source("R/wrapup.R")
  })
}
work <- tempfile("scene")
dir.create(work)
file.copy(dir(root, full.names = TRUE), work, recursive = TRUE)
old <- setwd(work)
verdict_out <- utils::capture.output(ok <- run_scene())
scene <- readLines(file.path(root, "R", "wrapup.R"))
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
test_that("each example prints its own contract line", {
  for (e in c("c-m4-p4-pipeline", "c-m4-p4-bench")) {
    run <- file.path("examples", e, "run.R")
    o <- utils::capture.output(source(run, local = new.env()))
    expect_match(o[length(o)], "^contract: ads-r-p4 .* OK$")
  }
})
test_that("the scene shows two OK contracts and reports TRUE", {
  expect_true(ok)
  expect_match(out, "ads-r-p4 pipeline matches golden/p4.json OK")
  expect_match(out, "ads-r-p4 dplyr == data.table OK")
  expect_match(out, "two contracts, both OK: TRUE")
})
test_that("verdict reports a failing oracle as FALSE", {
  txt <- utils::capture.output(res <- verdict(FALSE, "x"))
  expect_false(res)
  expect_match(txt, "contract: c-m4 x: FALSE")
})
setwd(old)
