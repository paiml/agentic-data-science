#' Read and bind the red and white Wine Quality tables.
#' @param red,white Paths to the two CSV files.
#' @export
read_wine <- function(red, white) {
  types <- readr::cols(quality = "i", color = "c", .default = "d")
  rbind(
    readr::read_csv(red, col_types = types),
    readr::read_csv(white, col_types = types)
  )
}

#' Stop on a missing value, a quality outside 0..10, or an unknown colour.
#' @param df Wine tibble.
#' @return `df`, unchanged, when valid.
#' @export
validate_wine <- function(df) {
  if (anyNA(df)) stop("wine data has missing values")
  if (any(df$quality < 0L | df$quality > 10L)) stop("quality outside 0..10")
  if (!all(df$color %in% c("red", "white"))) stop("unknown color")
  df
}

#' Deterministic split: every fifth row is a test row.
#' @param df Wine tibble.
#' @export
split_wine <- function(df) {
  is_test <- seq_len(nrow(df)) %% 5L == 0L
  list(train = df[!is_test, ], test = df[is_test, ])
}

#' Validate, split, fit a linear quality model, score it on the test rows.
#' @param red,white Paths to the two CSV files.
#' @export
pipeline_wine <- function(red, white) {
  df <- validate_wine(read_wine(red, white))
  s <- split_wine(df)
  fit <- stats::lm(quality ~ ., data = s$train)
  pred <- stats::predict(fit, newdata = s$test)
  m <- agenticds::regression_metrics(s$test$quality, pred)
  by_color <- tapply(df$quality, df$color, mean)
  list(
    n_rows = nrow(df), n_train = nrow(s$train), n_test = nrow(s$test),
    rmse = m$rmse, r2 = m$r2,
    mean_quality_by_color = as.list(by_color)
  )
}

#' Mean quality and count per colour with dplyr.
#' @param df Wine tibble.
#' @export
aggregate_dplyr <- function(df) {
  df |>
    dplyr::group_by(dplyr::across(dplyr::all_of("color"))) |>
    dplyr::summarise(
      dplyr::across(dplyr::all_of("quality"), mean, .names = "mean_quality"),
      n = dplyr::n(), .groups = "drop"
    ) |>
    as.data.frame()
}

#' Mean quality and count per colour with data.table.
#' @param df Wine tibble.
#' @export
aggregate_data_table <- function(df) {
  dt <- data.table::as.data.table(df)
  out <- dt[, list(
    mean_quality = mean(get("quality")), n = length(get("quality"))
  ), by = "color"]
  as.data.frame(out[order(out$color), ])
}

#' Median wall time of the two aggregations.
#' @param df Wine tibble.
#' @param reps Repetitions per engine.
#' @export
bench_wine <- function(df, reps = 20L) {
  time_one <- function(f) {
    stats::median(vapply(seq_len(reps), function(i) {
      unname(system.time(f(df))[["elapsed"]])
    }, numeric(1)))
  }
  data.frame(
    engine = c("dplyr", "data.table"),
    seconds = c(time_one(aggregate_dplyr), time_one(aggregate_data_table))
  )
}

#' Write the golden JSON (no timings).
#' @param res Output of `pipeline_wine()`.
#' @param path Output path.
#' @export
write_golden <- function(res, path) {
  writeLines(
    as.character(jsonlite::toJSON(res, auto_unbox = TRUE, digits = NA, pretty = TRUE)),
    path
  )
}

#' Write the pipeline report as an `ads:Artifact` in Turtle.
#' @param res Output of `pipeline_wine()`.
#' @param path Output path.
#' @export
report_ttl <- function(res, path) {
  writeLines(c(
    "@prefix ads: <https://paiml.com/ns/ads#> .",
    "@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .",
    "",
    "<https://paiml.com/ns/ads#wine-report> a ads:Artifact ;",
    "  ads:schemaVersion \"1\" ;",
    "  ads:generatedBy \"agenticds::pipeline_wine\" ;",
    sprintf("  ads:rmse \"%.10f\"^^xsd:decimal ;", res$rmse),
    sprintf("  ads:rows \"%d\"^^xsd:integer .", res$n_rows)
  ), path)
}
