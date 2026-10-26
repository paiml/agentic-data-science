root <- normalizePath(testthat::test_path("..", ".."))
h <- new.env()
sys.source(file.path(root, "R", "helpers.R"), envir = h)
d <- h$load_clean(file.path(root, "data", "penguins.csv"))
g <- jsonlite::fromJSON(file.path(root, "data", "p2.json"))
b <- h$ols_closed_form(d$flipper_length_mm, d$body_mass_g)
m <- h$regression_metrics(d$body_mass_g, h$fit_line(d)$fitted)
sp <- stats::lm(body_mass_g ~ flipper_length_mm + species, d)
sp_m <- h$regression_metrics(d$body_mass_g, stats::fitted(sp))

test_that("drop_na keeps 342 rows", {
  expect_equal(nrow(d), 342L)
})
test_that("ols_closed_form matches the golden fit", {
  expect_named(b, c("intercept", "slope"))
  expect_equal(b[["intercept"]], g$ols$intercept, tolerance = 1e-8)
  expect_equal(b[["slope"]], g$ols$slope, tolerance = 1e-8)
})
test_that("ols_closed_form matches lm within 1e-8", {
  ref <- stats::coef(stats::lm(body_mass_g ~ flipper_length_mm, d))
  expect_equal(unname(b), unname(ref), tolerance = 1e-8)
})
test_that("metrics match the golden line scores", {
  expect_equal(m$rmse, g$metrics$ols$rmse, tolerance = 1e-8)
  expect_equal(m$r2, g$metrics$ols$r2, tolerance = 1e-8)
})
test_that("regression_metrics gives RMSE and R squared", {
  toy <- h$regression_metrics(c(1, 2, 3, 4), c(1, 2, 3, 6))
  expect_equal(toy$rmse, 1)
  expect_equal(toy$r2, 1 - 4 / 5)
})
test_that("the species model matches the golden scores", {
  expect_equal(sp_m$rmse, g$metrics$species$rmse, tolerance = 1e-8)
  expect_equal(sp_m$r2, g$metrics$species$r2, tolerance = 1e-8)
  expect_equal(
    unname(stats::coef(sp)[["flipper_length_mm"]]),
    g$species_model$flipper_length_mm,
    tolerance = 1e-8
  )
})
