library(testthat)
root <- normalizePath(testthat::test_path("..", ".."))
if (!exists("run_scene")) {
  withr::with_dir(root, {
    source("R/helpers.R")
    source("R/report.R")
  })
}
work <- tempfile("scene")
dir.create(work)
file.copy(dir(root, full.names = TRUE), work, recursive = TRUE)
old <- setwd(work)
verdict_out <- utils::capture.output(ok <- run_scene())
scene <- readLines(file.path(root, "R", "report.R"))
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
test_that("the scene prints the artifact and a green verdict", {
  expect_true(ok)
  expect_match(out, "a ads:Artifact")
  expect_match(out, "ads:schemaVersion \"1\"")
  expect_match(out, "ads:generatedBy \"agenticds::pipeline_wine\"")
  expect_match(out, "ads:rows \"6497\"\\^\\^xsd:integer")
  expect_match(out, "artifact matches the golden ttl: TRUE")
})
test_that("the artifact carries the golden rmse to ten digits", {
  g <- jsonlite::fromJSON("data/p4.json")
  want <- sprintf("ads:rmse \"%.10f\"", g$rmse)
  ttl <- readLines("data/p4-artifact.ttl")
  expect_true(any(grepl(want, ttl, fixed = TRUE)))
})
setwd(old)
