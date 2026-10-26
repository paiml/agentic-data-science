library(testthat)
root <- normalizePath(testthat::test_path("..", ".."))
old <- setwd(root)
if (!exists("run_scene")) source("R/gates.R")
scene_src <- readLines("R/gates.R")
scene_lines <- length(scene_src)
setwd(old)
h <- mget(c(
  "run_scene",
  "verdict",
  "tests_pass",
  "parses_ok",
  "exports_match"
), inherits = TRUE)
work <- tempfile("scene")
dir.create(work)
files <- list.files(root, full.names = TRUE)
file.copy(files, work, recursive = TRUE)
old <- setwd(work)
verdict_out <- utils::capture.output(ok <- h$run_scene())
out <- paste(verdict_out, collapse = " ")

test_that("the scene file is 59 columns wide at most", {
  expect_lte(max(nchar(scene_src)), 59L)
})
test_that("the scene file fits the screen, 25 lines or fewer", {
  expect_lte(scene_lines, 25L)
})
test_that("tests, parse and exports are all TRUE", {
  expect_match(out, "tests +parse +exports")
  expect_match(out, "TRUE +TRUE +TRUE")
})
test_that("the scene verdict is TRUE", {
  expect_true(ok)
  expect_match(out, "gates green: TRUE")
})
test_that("verdict prints a failure as FALSE and returns it", {
  res <- utils::capture.output(r <- h$verdict("x: ", FALSE))
  expect_false(r)
  expect_match(res, "x: FALSE")
})
test_that("tests_pass is FALSE on failures, errors on no tests", {
  bad <- tempfile("bad")
  dir.create(bad)
  expect_error(h$tests_pass(bad), "No test files")
  code <- 'test_that("x", expect_equal(1, 2))'
  writeLines(code, file.path(bad, "test-x.R"))
  expect_false(h$tests_pass(bad))
})
test_that("parses_ok is FALSE for a file that does not parse", {
  f <- tempfile(fileext = ".R")
  writeLines("x <- (", f)
  expect_false(h$parses_ok(f))
})
test_that("exports_match is FALSE when tags and NAMESPACE differ", {
  f <- tempfile(fileext = ".R")
  writeLines(c("#' @export", "a <- function() 1"), f)
  ns <- tempfile()
  writeLines("export(b)", ns)
  expect_false(h$exports_match(f, ns))
  writeLines("export(a)", ns)
  expect_true(h$exports_match(f, ns))
})
setwd(old)
