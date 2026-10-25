#' Read the fixed fold assignment (one fold per clean row).
#' @param path Path to folds.csv.
#' @return Integer vector of fold ids.
#' @export
read_folds <- function(path) {
  readr::read_csv(
    path,
    col_types = readr::cols(row = "i", fold = "i")
  )$fold
}

#' Closed-form simple OLS via the normal equations.
#' @param x,y Numeric vectors.
#' @return Named vector `intercept`, `slope`.
#' @export
ols_closed_form <- function(x, y) {
  design <- cbind(1, x)
  b <- solve(crossprod(design), crossprod(design, y))
  c(intercept = b[[1]], slope = b[[2]])
}

species_formula <- body_mass_g ~ flipper_length_mm + species

#' Fit body mass on flipper length and species with parsnip's
#' linear_reg().
#' @param df A cleaned penguins tibble.
#' @return Named coefficient vector.
#' @export
fit_lm_species <- function(df) {
  fit <- parsnip::fit(
    parsnip::set_engine(parsnip::linear_reg(), "lm"),
    species_formula,
    data = df
  )
  fit$fit$coefficients
}

#' RMSE and R squared of predictions.
#' @param y,yhat Observed and predicted values.
#' @export
regression_metrics <- function(y, yhat) {
  sse <- sum((y - yhat)^2)
  list(
    rmse = sqrt(sse / length(y)),
    r2 = 1 - sse / sum((y - mean(y))^2)
  )
}

predict_species <- function(train, test) {
  fit <- parsnip::fit(
    parsnip::set_engine(parsnip::linear_reg(), "lm"),
    species_formula,
    data = train
  )
  stats::predict(fit, new_data = test)$.pred
}

predict_ols <- function(train, test) {
  b <- ols_closed_form(train$flipper_length_mm, train$body_mass_g)
  b[["intercept"]] + b[["slope"]] * test$flipper_length_mm
}

#' Pooled out-of-fold RMSE over a fixed fold assignment.
#' @param df A cleaned penguins tibble.
#' @param folds Fold id per row.
#' @param with_species Include species in the model.
#' @export
cv_rmse <- function(df, folds, with_species) {
  predictor <- if (with_species) predict_species else predict_ols
  pred <- numeric(nrow(df))
  for (k in sort(unique(folds))) {
    pred[folds == k] <- predictor(
      df[folds != k, ],
      df[folds == k, ]
    )
  }
  regression_metrics(df$body_mass_g, pred)$rmse
}

#' Serialise P2 results to the golden JSON layout.
#' @param df A cleaned penguins tibble.
#' @param folds Fold id per row.
#' @export
p2_json <- function(df, folds) {
  b <- ols_closed_form(df$flipper_length_mm, df$body_mass_g)
  ols_fit <- b[["intercept"]] + b[["slope"]] * df$flipper_length_mm
  sp <- fit_lm_species(df)
  sp_fit <- predict_species(df, df)
  jsonlite::toJSON(
    list(
      ols = list(
        intercept = b[["intercept"]],
        slope = b[["slope"]]
      ),
      species_model = as.list(sp),
      metrics = list(
        ols = regression_metrics(df$body_mass_g, ols_fit),
        species = regression_metrics(df$body_mass_g, sp_fit)
      ),
      cv_rmse = list(
        ols = cv_rmse(df, folds, FALSE),
        species = cv_rmse(df, folds, TRUE)
      )
    ),
    auto_unbox = TRUE, digits = NA, pretty = TRUE
  )
}
