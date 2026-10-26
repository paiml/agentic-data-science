library(testthat)
library(testthat)
root <- normalizePath(testthat::test_path("..", ".."))
old <- setwd(root)
if (!exists("run_scene")) {
  source("R/helpers.R")
  source("R/ticket.R")
}
scene_lines <- length(readLines("R/ticket.R"))
scene_wide <- max(nchar(readLines("R/ticket.R")))
setwd(old)
work <- tempfile("scene")
dir.create(work)
file.copy(file.path(root, "data"), work, recursive = TRUE)
old <- setwd(work)
verdict_out <- utils::capture.output(ok <- run_scene())

test_that("the scene file fits the screen, 25 lines, 59 cols", {
  expect_lte(scene_lines, 25L)
  expect_lte(scene_wide, 59L)
})
test_that("checksums verify on the shipped data", {
  expect_true(check_sums("data"))
})
test_that("a changed byte fails the checksum", {
  bad <- tempfile("bad")
  dir.create(bad)
  file.copy(list.files("data", full.names = TRUE), bad)
  cat("x", file = file.path(bad, "penguins.csv"), append = TRUE)
  expect_false(check_sums(bad))
})
test_that("golden n equals the cleaned species counts", {
  g <- jsonlite::fromJSON("data/p1.json")
  n <- vapply(g$species, function(s) s$n, numeric(1))
  expect_equal(unname(n), c(151, 68, 123))
  expect_equal(sum(n), 342)
})
test_that("the scene reports TRUE and the 344 -> 342 drop", {
  expect_true(ok)
  out <- paste(verdict_out, collapse = " ")
  expect_match(out, "rows 344 -> 342")
  expect_match(out, "oracle matches: TRUE")
})
test_that("verdict prints a failure as FALSE and returns it", {
  out <- utils::capture.output(r <- verdict("x: ", FALSE))
  expect_false(r)
  expect_match(out, "x: FALSE")
})
setwd(old)
