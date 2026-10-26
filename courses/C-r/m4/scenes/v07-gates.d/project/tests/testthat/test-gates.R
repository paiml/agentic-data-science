library(testthat)
root <- normalizePath(testthat::test_path("..", ".."))
if (!exists("run_scene")) {
  withr::with_dir(root, {
    source("R/helpers.R")
    source("R/gates.R")
  })
}
work <- tempfile("scene")
dir.create(work)
file.copy(dir(root, full.names = TRUE), work, recursive = TRUE)
old <- setwd(work)
verdict_out <- utils::capture.output(ok <- run_scene())
scene <- readLines(file.path(root, "R", "gates.R"))
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
test_that("the scene shows checksums, shape and a green verdict", {
  expect_true(ok)
  expect_match(out, "SHA256SUMS: TRUE")
  expect_match(out, "TRUE +TRUE +TRUE")
  expect_match(out, "gates green: TRUE")
})
test_that("the data checksums verify, a changed byte fails", {
  expect_true(check_sums("data"))
  bad <- tempfile("bad")
  dir.create(bad)
  file.copy(list.files("data", full.names = TRUE), bad)
  red <- file.path(bad, "winequality-red.csv")
  cat("x", file = red, append = TRUE)
  expect_false(check_sums(bad))
})
test_that("shape_ok needs the class and both required fields", {
  ttl <- paste(readLines("data/p4-artifact.ttl"), collapse = "\n")
  expect_true(all(shape_ok(ttl)))
  expect_false(all(shape_ok("a ads:Artifact ;")))
  expect_false(shape_ok("x")[["ads:generatedBy"]])
})
test_that("read_ttl joins lines, has_num finds a 10-digit number", {
  ttl <- read_ttl("data/p4-artifact.ttl")
  expect_length(ttl, 1L)
  expect_true(grepl("\n", ttl, fixed = TRUE))
  expect_true(has_num("rmse 0.7602516000 .", 0.7602516))
  expect_false(has_num("rmse 0.5", 0.7602516))
})
setwd(old)
