# helpers: plumbing only, nothing here is shown on camera
numeric_cols <- c(
  "bill_length_mm", "bill_depth_mm",
  "flipper_length_mm", "body_mass_g"
)

check_sums <- function(dir) {
  old <- setwd(dir)
  on.exit(setwd(old))
  args <- c("-c", "--quiet", "SHA256SUMS")
  system2("sha256sum", args, stdout = FALSE, stderr = FALSE) == 0
}

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

na_policy <- function(df) {
  dplyr::filter(
    df,
    dplyr::if_all(dplyr::all_of(numeric_cols), ~ !is.na(.x))
  )
}

summarise_by_species <- function(df, sd_fn = stats::sd) {
  df |>
    dplyr::group_by(dplyr::across(dplyr::all_of("species"))) |>
    dplyr::summarise(
      n = dplyr::n(),
      dplyr::across(
        dplyr::all_of(numeric_cols),
        list(mean = mean, sd = sd_fn),
        .names = "{.col}_{.fn}"
      ),
      .groups = "drop"
    )
}

summary_json <- function(s) {
  species <- lapply(seq_len(nrow(s)), function(i) {
    cols <- lapply(numeric_cols, function(col) {
      list(
        mean = s[[paste0(col, "_mean")]][i],
        sd = s[[paste0(col, "_sd")]][i]
      )
    })
    c(list(n = s$n[i]), stats::setNames(cols, numeric_cols))
  })
  jsonlite::toJSON(
    list(species = stats::setNames(species, s$species)),
    auto_unbox = TRUE, digits = NA, pretty = TRUE, na = "null"
  )
}

count_species <- function(df) {
  tab <- table(df$species)
  stats::setNames(as.numeric(tab), names(tab))
}

verdict <- function(msg, ok) {
  paint <- if (ok) cli::col_green else cli::col_red
  cat(paint(cli::style_bold(paste0(msg, ok))), "\n")
  invisible(ok)
}

# the p1 checks as a named logical vector, one entry per test
p1_suite <- function(policy = na_policy, sd_fn = stats::sd) {
  raw <- read_penguins("data/penguins.csv")
  gold <- jsonlite::fromJSON("data/p1.json")
  d <- policy(raw)
  s <- summarise_by_species(d, sd_fn)
  doc <- jsonlite::fromJSON(as.character(summary_json(s)))
  want <- unlist(gold)
  got <- unlist(doc)[names(want)]
  near <- isTRUE(max(abs(got - want)) < 1e-9)
  c(
    "read_penguins loads 344 typed rows" =
      nrow(raw) == 344 && is.integer(raw$year),
    "na_policy drops numeric NA rows only" =
      nrow(d) == 342 && sum(is.na(d$sex)) == 9,
    "na_policy keeps a clean frame unchanged" =
      identical(policy(na_policy(raw)), na_policy(raw)),
    "summarise gives n, mean and sample sd" =
      identical(s$n, c(151L, 68L, 123L)) && near,
    "summary_json names the three species" =
      identical(names(doc$species), names(gold$species)),
    "summary matches the golden within 1e-9" =
      near && length(unlist(doc)) == length(want)
  )
}
