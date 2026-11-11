csv_path <- file.path(Sys.getenv("LAB_DIR", unset = getwd()), "data", "penguins-mini.csv")

# Hand-checkable fixture: Adelie has 3 complete rows + 1 all-NA row, Gentoo 2, Chinstrap 3.
expect_tbl <- list(
  Adelie = list(n = 3L, bill_length_mm = c(40, 1), bill_depth_mm = c(19, 1),
                flipper_length_mm = c(185, 5), body_mass_g = c(3700, 100)),
  Chinstrap = list(n = 3L, bill_length_mm = c(50, 2), bill_depth_mm = c(19, 1),
                   flipper_length_mm = c(195, 5), body_mass_g = c(3700, 200)),
  Gentoo = list(n = 2L, bill_length_mm = c(48, sqrt(8)), bill_depth_mm = c(15, sqrt(2)),
                flipper_length_mm = c(220, sqrt(50)), body_mass_g = c(4900, sqrt(80000)))
)
one_row <- function() {
  tibble::tibble(species = "Adelie", island = "x", bill_length_mm = 1,
    bill_depth_mm = 2, flipper_length_mm = 3, body_mass_g = 4, sex = "male", year = 2007L)
}

test_that("read_penguins (given) loads 9 typed rows", {
  df <- read_penguins(csv_path)
  expect_equal(nrow(df), 9L)
  expect_true(is.numeric(df$bill_length_mm))
  expect_equal(sum(is.na(df$bill_length_mm)), 1L)
})

test_that("TODO 1 na_policy drops rows with a missing measurement", {
  clean <- na_policy(read_penguins(csv_path))
  expect_equal(nrow(clean), 8L)
  for (col in numeric_cols) expect_true(is.numeric(clean[[col]]))
})

test_that("TODO 1 na_policy keeps a row whose only gap is sex", {
  clean <- na_policy(read_penguins(csv_path))
  expect_equal(sum(is.na(clean$sex)), 1L)
  keep <- one_row()
  keep$sex <- NA_character_
  expect_equal(nrow(na_policy(keep)), 1L)
})

test_that("TODO 1 na_policy: a gap in any one measurement drops the row", {
  for (col in numeric_cols) {
    gap <- one_row()
    gap[[col]] <- NA_real_
    expect_equal(nrow(na_policy(gap)), 0L, info = col)
  }
})

test_that("TODO 2 summarise_by_species: species order and counts", {
  s <- summarise_by_species(na_policy(read_penguins(csv_path)))
  expect_equal(s$species, c("Adelie", "Chinstrap", "Gentoo"))
  for (i in seq_len(nrow(s))) expect_equal(s$n[i], expect_tbl[[s$species[i]]]$n)
})

test_that("TODO 2 summarise_by_species: means and SAMPLE sd (n - 1)", {
  s <- summarise_by_species(na_policy(read_penguins(csv_path)))
  for (i in seq_len(nrow(s))) {
    for (col in numeric_cols) {
      e <- expect_tbl[[s$species[i]]][[col]]
      expect_equal(s[[paste0(col, "_mean")]][i], e[1], tolerance = 1e-9)
      expect_equal(s[[paste0(col, "_sd")]][i], e[2], tolerance = 1e-9)
    }
  }
})

test_that("TODO 3 summary_json: layout, order and values", {
  s <- summarise_by_species(na_policy(read_penguins(csv_path)))
  out <- jsonlite::fromJSON(summary_json(s))
  expect_equal(names(out), "species")
  expect_equal(names(out$species), c("Adelie", "Chinstrap", "Gentoo"))
  for (sp in names(out$species)) {
    e <- expect_tbl[[sp]]
    expect_equal(out$species[[sp]]$n, e$n)
    expect_equal(names(out$species[[sp]]), c("n", numeric_cols))
    for (col in numeric_cols) {
      expect_equal(out$species[[sp]][[col]]$mean, e[[col]][1], tolerance = 1e-9)
      expect_equal(out$species[[sp]][[col]]$sd, e[[col]][2], tolerance = 1e-9)
    }
  }
})
