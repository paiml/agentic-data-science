measure_cols <- c("bill_length_mm", "bill_depth_mm", "flipper_length_mm", "body_mass_g")

#' Read the fixed train/test split (one label per clean row).
#' @param path Path to split.csv.
#' @export
read_split <- function(path) {
  readr::read_csv(path, col_types = readr::cols(row = "i", set = "c"))$set
}

#' Read the fixed initial centroids as a matrix (one row per cluster).
#' @param path Path to centroids.csv.
#' @export
read_centroids <- function(path) {
  df <- readr::read_csv(path, col_types = readr::cols(cluster = "i", .default = "d"))
  as.matrix(df[, measure_cols])
}

#' Confusion matrix with truth in rows and prediction in columns.
#' @param truth,pred Factors with the same levels.
#' @export
confusion <- function(truth, pred) {
  table(truth = truth, pred = pred)
}

#' Share of correct predictions.
#' @param truth,pred Factors with the same levels.
#' @export
accuracy <- function(truth, pred) {
  mean(truth == pred)
}

#' Fit a species decision tree (rpart through parsnip, deterministic).
#' @param train Training rows of the cleaned penguins tibble.
#' @export
fit_species_clf <- function(train) {
  train$species <- factor(train$species)
  spec <- parsnip::set_mode(
    parsnip::set_engine(parsnip::decision_tree(), "rpart"), "classification"
  )
  parsnip::fit(spec, species ~ bill_length_mm + bill_depth_mm + flipper_length_mm + body_mass_g,
    data = train
  )
}

#' Predict species classes.
#' @param fit Output of `fit_species_clf()`.
#' @param test Rows to classify.
#' @export
predict_species_clf <- function(fit, test) {
  stats::predict(fit, new_data = test, type = "class")$.pred_class
}

#' Lloyd k-means on z-scored features from fixed initial centroids.
#' @param df Cleaned penguins tibble.
#' @param centroids Matrix of initial centroids in raw units.
#' @param max_iter Iteration cap.
#' @export
kmeans_fixed <- function(df, centroids, max_iter = 100L) {
  z <- scale(as.matrix(df[, measure_cols]))
  centre <- attr(z, "scaled:center")
  spread <- attr(z, "scaled:scale")
  cen <- scale(centroids, center = centre, scale = spread)
  cluster <- rep(0L, nrow(z))
  for (iter in seq_len(max_iter)) {
    dist <- vapply(seq_len(nrow(cen)), function(k) {
      rowSums((z - rep(cen[k, ], each = nrow(z)))^2)
    }, numeric(nrow(z)))
    new_cluster <- max.col(-dist, ties.method = "first")
    if (all(new_cluster == cluster)) break
    cluster <- new_cluster
    for (k in seq_len(nrow(cen))) {
      members <- cluster == k
      if (any(members)) cen[k, ] <- colMeans(z[members, , drop = FALSE])
    }
  }
  objective <- sum((z - cen[cluster, , drop = FALSE])^2)
  list(
    cluster = as.integer(cluster),
    centers = sweep(sweep(cen, 2, spread, `*`), 2, centre, `+`),
    objective = objective
  )
}

#' Serialise P3 results to the golden JSON layout.
#' @param df Cleaned penguins tibble.
#' @param split Train/test label per row.
#' @param centroids Initial centroid matrix.
#' @export
p3_json <- function(df, split, centroids) {
  fit <- fit_species_clf(df[split == "train", ])
  pred <- predict_species_clf(fit, df[split == "test", ])
  truth <- factor(df$species[split == "test"], levels = levels(pred))
  cm <- confusion(truth, pred)
  km <- kmeans_fixed(df, centroids)
  jsonlite::toJSON(
    list(
      accuracy = accuracy(truth, pred),
      confusion = unname(unclass(cm)),
      classes = levels(pred),
      kmeans = list(
        objective = km$objective,
        cluster_sizes = as.integer(tabulate(km$cluster, nbins = nrow(centroids)))
      )
    ),
    auto_unbox = TRUE, digits = NA, pretty = TRUE
  )
}
