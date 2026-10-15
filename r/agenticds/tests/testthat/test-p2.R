root_dir <- function() {
  Sys.getenv("ADS_ROOT", unset = normalizePath(file.path("..", "..", "..", "..")))
}
clean_df <- function() {
  path <- file.path(root_dir(), "datasets", "penguins", "penguins.csv")
  agenticds::na_policy(agenticds::read_penguins(path))
}
folds_path <- function() file.path(root_dir(), "datasets", "fixtures", "folds.csv")

test_that("read_folds returns one fold in 1..5 per clean row", {
  f <- read_folds(folds_path())
  expect_equal(length(f), 342L)
  expect_equal(sort(unique(f)), 1:5)
})

test_that("ols_closed_form matches lm within 1e-8", {
  df <- clean_df()
  b <- ols_closed_form(df$flipper_length_mm, df$body_mass_g)
  ref <- stats::coef(stats::lm(body_mass_g ~ flipper_length_mm, data = df))
  expect_equal(unname(b), unname(ref), tolerance = 1e-8)
  expect_equal(names(b), c("intercept", "slope"))
})

test_that("fit_lm_species returns the lm coefficients with species", {
  df <- clean_df()
  b <- fit_lm_species(df)
  ref <- stats::coef(stats::lm(body_mass_g ~ flipper_length_mm + species, data = df))
  expect_equal(unname(b), unname(ref), tolerance = 1e-8)
  expect_equal(length(b), 4L)
})

test_that("regression_metrics gives RMSE and R squared", {
  m <- regression_metrics(c(1, 2, 3, 4), c(1, 2, 3, 6))
  expect_equal(m$rmse, 1)
  expect_equal(m$r2, 1 - 4 / 5)
})

test_that("cv_rmse pools out-of-fold errors over the fixed folds", {
  df <- clean_df()
  f <- read_folds(folds_path())
  sq <- 0
  for (k in 1:5) {
    fit <- stats::lm(body_mass_g ~ flipper_length_mm, data = df[f != k, ])
    pred <- stats::predict(fit, newdata = df[f == k, ])
    sq <- sq + sum((df$body_mass_g[f == k] - pred)^2)
  }
  expect_equal(cv_rmse(df, f, with_species = FALSE), sqrt(sq / nrow(df)), tolerance = 1e-6)
  sq <- 0
  for (k in 1:5) {
    fit <- stats::lm(body_mass_g ~ flipper_length_mm + species, data = df[f != k, ])
    pred <- stats::predict(fit, newdata = df[f == k, ])
    sq <- sq + sum((df$body_mass_g[f == k] - pred)^2)
  }
  expect_equal(cv_rmse(df, f, with_species = TRUE), sqrt(sq / nrow(df)), tolerance = 1e-6)
})

test_that("p2 summary matches the committed golden", {
  golden <- jsonlite::fromJSON(file.path(root_dir(), "datasets", "golden", "p2.json"))
  got <- jsonlite::fromJSON(p2_json(clean_df(), read_folds(folds_path())))
  expect_equal(got$ols$intercept, golden$ols$intercept, tolerance = 1e-8)
  expect_equal(got, golden, tolerance = 1e-6)
})
