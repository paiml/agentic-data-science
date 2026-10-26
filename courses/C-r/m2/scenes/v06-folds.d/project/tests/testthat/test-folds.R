library(testthat)
root <- normalizePath(testthat::test_path("..", ".."))
old <- setwd(root)
source("R/helpers.R")
source("R/folds.R")
scene <- readLines("R/folds.R")
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
test_that("the shipped folds are 5 balanced folds over 342 rows", {
  f <- read_folds("data/folds.csv")
  expect_length(f, 342L)
  expect_equal(as.vector(table(f)), c(69L, 69L, 68L, 68L, 68L))
  expect_identical(f[1:10], rep(1:5, 2))
})
test_that("fixed-fold CV matches the golden CV RMSE", {
  f <- read_folds("data/folds.csv")
  expect_equal(cv_rmse(d, f), g$cv_rmse$ols, tolerance = 1e-8)
  expect_equal(
    cv_rmse(d, f, species = TRUE), g$cv_rmse$species,
    tolerance = 1e-8
  )
})
test_that("fixed folds repeat, random seeds differ", {
  expect_true(ok)
  expect_match(txt, "fixed folds: 394.3 then 394.3")
  expect_match(txt, "random seeds: 393.8 then 397.1")
  expect_match(txt, "folds fixed, CV repeatable: TRUE")
})
test_that("one seed gives one split, two seeds two splits", {
  expect_identical(random_folds(342, 1), random_folds(342, 1))
  s1 <- random_folds(342, 1)
  expect_false(identical(s1, random_folds(342, 2)))
})
test_that("the repeat check fails when the seed is ignored", {
  src <- readLines("R/helpers.R")
  bad <- sub("set.seed(seed)", "invisible(seed)", src, fixed = TRUE)
  expect_false(identical(src, bad))
  e <- new.env()
  eval(parse(text = bad), e)
  expect_false(identical(
    e$random_folds(342, 1), e$random_folds(342, 1)
  ))
})
test_that("random splits move the CV RMSE, fixed folds do not", {
  f <- read_folds("data/folds.csv")
  again <- read_folds("data/folds.csv")
  expect_identical(cv_rmse(d, f), cv_rmse(d, again))
  r1 <- cv_rmse(d, random_folds(342, 1))
  r2 <- cv_rmse(d, random_folds(342, 2))
  expect_false(isTRUE(all.equal(r1, r2, tolerance = 1e-8)))
  golden <- g$cv_rmse$ols
  expect_false(isTRUE(all.equal(r1, golden, tolerance = 1e-8)))
})
test_that("regression_metrics gives RMSE and R squared", {
  toy <- regression_metrics(c(1, 2, 3, 4), c(1, 2, 3, 6))
  expect_equal(toy$rmse, 1)
  expect_equal(toy$r2, 1 - 4 / 5)
})
test_that("the closed form matches the golden OLS", {
  b <- ols_closed_form(d$flipper_length_mm, d$body_mass_g)
  expect_equal(b[["slope"]], g$ols$slope, tolerance = 1e-8)
})
test_that("verdict returns and prints a failure as FALSE", {
  res <- utils::capture.output(r <- verdict("x", FALSE))
  expect_false(r)
  expect_match(res, "x: FALSE")
})
setwd(old)
