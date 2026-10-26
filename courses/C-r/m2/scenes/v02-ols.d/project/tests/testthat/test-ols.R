library(testthat)
root <- normalizePath(testthat::test_path("..", ".."))
old <- setwd(root)
source("R/helpers.R")
source("R/ols.R")
scene <- readLines("R/ols.R")
scene_lines <- length(scene)
setwd(old)
work <- tempfile("scene")
dir.create(work)
file.copy(dir(root, full.names = TRUE), work, recursive = TRUE)
old <- setwd(work)
out <- utils::capture.output(ok <- run_scene())
txt <- paste(out, collapse = " ")
g <- jsonlite::fromJSON("data/p2.json")
d <- load_clean("data/penguins.csv")

test_that("the scene file fits the screen, 25 lines or fewer", {
  expect_lte(scene_lines, 25L)
  expect_lte(max(nchar(scene)), 59L)
})
test_that("drop_na keeps 342 rows (D14)", {
  expect_equal(nrow(d), 342L)
})
test_that("closed form equals lm within 1e-8", {
  b <- ols_closed_form(d$flipper_length_mm, d$body_mass_g)
  ref <- stats::coef(stats::lm(body_mass_g ~ flipper_length_mm, d))
  expect_equal(unname(b), unname(ref), tolerance = 1e-8)
})
test_that("the fit reproduces the golden slope and intercept", {
  fit <- fit_line(d)
  expect_equal(fit$b[["slope"]], g$ols$slope, tolerance = 1e-8)
  expect_equal(
    fit$b[["intercept"]], g$ols$intercept,
    tolerance = 1e-8
  )
  expect_length(fit$fitted, 342L)
})
test_that("regression_metrics gives RMSE and R squared", {
  toy <- regression_metrics(c(1, 2, 3, 4), c(1, 2, 3, 6))
  expect_equal(toy$rmse, 1)
  expect_equal(toy$r2, 1 - 4 / 5)
})
test_that("the line scores R squared 0.759 as the golden says", {
  m <- regression_metrics(d$body_mass_g, fit_line(d)$fitted)
  expect_equal(m$r2, g$metrics$ols$r2, tolerance = 1e-8)
  expect_equal(round(m$r2, 3), 0.759)
})
test_that("the scene reports TRUE with slope 49.69 and R 0.759", {
  expect_true(ok)
  expect_match(txt, "slope 49.69 g/mm")
  expect_match(txt, "R squared 0.759")
  expect_match(txt, "R squared matches golden: TRUE")
})
test_that("verdict returns and prints a failure as FALSE", {
  res <- utils::capture.output(r <- verdict("x", FALSE))
  expect_false(r)
  expect_match(res, "x: FALSE")
})
setwd(old)
