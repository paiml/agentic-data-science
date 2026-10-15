numeric_cols <- c("bill_length_mm", "bill_depth_mm", "flipper_length_mm", "body_mass_g")

#' Read the Palmer Penguins CSV with explicit column types.
#' @param path Path to penguins.csv.
#' @return A tibble.
#' @export
read_penguins <- function(path) {
  readr::read_csv(
    path,
    col_types = readr::cols(
      species = "c", island = "c", bill_length_mm = "d", bill_depth_mm = "d",
      flipper_length_mm = "d", body_mass_g = "d", sex = "c", year = "i"
    ),
    na = "NA"
  )
}

#' Drop rows with a missing value in any numeric measurement column.
#' @param df A penguins tibble.
#' @export
na_policy <- function(df) {
  dplyr::filter(df, dplyr::if_all(dplyr::all_of(numeric_cols), ~ !is.na(.x)))
}

#' Count, mean and sample standard deviation of each measurement, per species.
#' @param df A penguins tibble after `na_policy()`.
#' @export
summarise_by_species <- function(df) {
  df |>
    dplyr::group_by(dplyr::across(dplyr::all_of("species"))) |>
    dplyr::summarise(
      n = dplyr::n(),
      dplyr::across(
        dplyr::all_of(numeric_cols),
        list(mean = mean, sd = stats::sd),
        .names = "{.col}_{.fn}"
      ),
      .groups = "drop"
    )
}

#' Serialise the per-species summary to the golden JSON layout.
#' @param s Output of `summarise_by_species()`.
#' @export
summary_json <- function(s) {
  species <- lapply(seq_len(nrow(s)), function(i) {
    cols <- lapply(numeric_cols, function(col) {
      list(mean = s[[paste0(col, "_mean")]][i], sd = s[[paste0(col, "_sd")]][i])
    })
    c(list(n = s$n[i]), stats::setNames(cols, numeric_cols))
  })
  jsonlite::toJSON(
    list(species = stats::setNames(species, s$species)),
    auto_unbox = TRUE, digits = NA, pretty = TRUE
  )
}
