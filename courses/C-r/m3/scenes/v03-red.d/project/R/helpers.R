# helpers: plumbing only, nothing here is shown on camera
feats <- c(
  "bill_length_mm", "bill_depth_mm",
  "flipper_length_mm", "body_mass_g"
)

verdict <- function(msg, ok) {
  paint <- if (ok) cli::col_green else cli::col_red
  cat(paint(cli::style_bold(paste0(msg, ok))), "\n")
  invisible(ok)
}

load_clean <- function(path) {
  d <- readr::read_csv(path, show_col_types = FALSE)
  tidyr::drop_na(d, tidyr::all_of(feats))
}

read_split <- function(path) {
  readr::read_csv(path, show_col_types = FALSE)$set
}

fit_species_clf <- function(train) {
  train$species <- factor(train$species)
  spec <- parsnip::set_mode(
    parsnip::set_engine(parsnip::decision_tree(), "rpart"),
    "classification"
  )
  parsnip::fit(
    spec,
    species ~ bill_length_mm + bill_depth_mm +
      flipper_length_mm + body_mass_g,
    data = train
  )
}

predict_species_clf <- function(fit, test) {
  stats::predict(fit, new_data = test, type = "class")$.pred_class
}

list(
  feats = feats,
  verdict = verdict,
  load_clean = load_clean,
  read_split = read_split,
  fit_species_clf = fit_species_clf,
  predict_species_clf = predict_species_clf
)
