# Plumbing for the scene: not shown on camera.

model_cols <- c("flipper_length_mm", "body_mass_g")

load_clean <- function(path) {
  d <- readr::read_csv(path, show_col_types = FALSE)
  d <- tidyr::drop_na(d, tidyr::all_of(model_cols))
  dplyr::select(d, dplyr::all_of(c("species", model_cols)))
}

ols_closed_form <- function(x, y) {
  design <- cbind(1, x)
  b <- solve(crossprod(design), crossprod(design, y))
  c(intercept = b[[1]], slope = b[[2]])
}

regression_metrics <- function(y, yhat) {
  sse <- sum((y - yhat)^2)
  list(
    rmse = sqrt(sse / length(y)),
    r2 = 1 - sse / sum((y - mean(y))^2)
  )
}

read_folds <- function(path) {
  readr::read_csv(
    path,
    col_types = readr::cols(row = "i", fold = "i")
  )$fold
}

cv_rmse <- function(d, folds, species = FALSE) {
  terms <- c("flipper_length_mm", if (species) "species")
  fml <- stats::reformulate(terms, "body_mass_g")
  pred <- numeric(nrow(d))
  for (k in sort(unique(folds))) {
    train <- d[folds != k, ]
    test <- d[folds == k, ]
    fit <- parsnip::fit(parsnip::linear_reg(), fml, data = train)
    pred[folds == k] <- stats::predict(fit, new_data = test)$.pred
  }
  regression_metrics(d$body_mass_g, pred)$rmse
}

make_ids <- function(n) {
  pre <- c("b", "A", "a", "B", "c", "C")
  paste0(rep(pre, length.out = n), seq_len(n))
}

fold_by_id <- function(ids) {
  (order(order(ids)) - 1L) %% 5L + 1L
}

use_locale <- function(loc) {
  set <- suppressWarnings(Sys.setlocale("LC_COLLATE", loc))
  if (!nzchar(set)) {
    stop("locale not installed: ", loc, call. = FALSE)
  }
}

locale_run <- function(loc, ids, d, folds) {
  old <- Sys.getlocale("LC_COLLATE")
  on.exit(Sys.setlocale("LC_COLLATE", old))
  use_locale(loc)
  list(
    row = cv_rmse(d, folds),
    by_id = cv_rmse(d, fold_by_id(ids))
  )
}

verdict <- function(msg, ok) {
  txt <- cli::style_bold(paste0(msg, ": ", ok))
  col <- if (ok) cli::col_green else cli::col_red
  cat(col(txt), "\n")
  invisible(ok)
}
