root <- normalizePath(testthat::test_path("..", ".."))
h <- source(file.path(root, "R", "helpers.R"))$value

test_that("every R file in the project parses", {
  files <- list.files(file.path(root, "R"), full.names = TRUE)
  expect_true(h$parses_ok(files))
})

test_that("the export tags equal the NAMESPACE exports", {
  files <- list.files(file.path(root, "R"), full.names = TRUE)
  ns <- file.path(root, "NAMESPACE")
  expect_true(h$exports_match(files, ns))
})

test_that("verdict returns its flag", {
  out <- utils::capture.output(r <- h$verdict("x: ", TRUE))
  expect_true(r)
  expect_match(out, "x: TRUE")
})
