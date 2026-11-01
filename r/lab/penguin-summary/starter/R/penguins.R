numeric_cols <- c(
  "bill_length_mm", "bill_depth_mm",
  "flipper_length_mm", "body_mass_g"
)

#' Read the Palmer Penguins CSV with explicit column types.
#' @param path Path to penguins.csv.
#' @return A tibble.
#' @export
read_penguins <- function(path) {
  readr::read_csv(
    path,
    col_types = readr::cols(
      species = "c", island = "c", bill_length_mm = "d",
      bill_depth_mm = "d", flipper_length_mm = "d",
      body_mass_g = "d", sex = "c", year = "i"
    ),
    na = "NA"
  )
}

#' TODO 1. Drop rows with a missing value in any of `numeric_cols`.
#' A missing `sex` alone keeps the row.
#' @param df A penguins tibble.
na_policy <- function(df) {
  stop("TODO 1: implement na_policy()")
}

#' TODO 2. Per species (sorted): `n`, then `<col>_mean` and `<col>_sd`
#' (sample sd, n - 1) for each column of `numeric_cols`.
#' @param df A penguins tibble after `na_policy()`.
summarise_by_species <- function(df) {
  stop("TODO 2: implement summarise_by_species()")
}

#' TODO 3. Serialise the summary as
#' {"species": {"Adelie": {"n": 3, "bill_length_mm": {"mean": .., "sd": ..}, ...}}}
#' with species in the order of `s` and measurements in the order of `numeric_cols`.
#' @param s Output of `summarise_by_species()`.
summary_json <- function(s) {
  stop("TODO 3: implement summary_json()")
}
