penguins_csv <- function() {
  root <- Sys.getenv("ADS_ROOT", unset = normalizePath(file.path("..", "..", "..", "..")))
  file.path(root, "datasets", "penguins", "penguins.csv")
}

test_that("read_penguins loads 344 typed rows", {
  df <- read_penguins(penguins_csv())
  expect_equal(nrow(df), 344L)
  expect_true(is.numeric(df$body_mass_g))
  expect_true(is.character(df$species))
  expect_equal(sum(is.na(df$body_mass_g)), 2L)
})

test_that("na_policy drops rows with NA in any numeric column only", {
  df <- read_penguins(penguins_csv())
  out <- na_policy(df)
  expect_equal(nrow(out), 342L)
  expect_equal(sum(is.na(out$sex)), 9L)
})

test_that("na_policy keeps a frame with no missing values unchanged", {
  df <- tibble::tibble(
    species = "A", island = "x", bill_length_mm = 1, bill_depth_mm = 2,
    flipper_length_mm = 3, body_mass_g = 4, sex = NA_character_, year = 2007L
  )
  expect_equal(nrow(na_policy(df)), 1L)
})

test_that("summarise_by_species gives n, mean and sample sd per species", {
  s <- summarise_by_species(na_policy(read_penguins(penguins_csv())))
  expect_equal(s$species, c("Adelie", "Chinstrap", "Gentoo"))
  expect_equal(s$n, c(151L, 68L, 123L))
  expect_equal(s$body_mass_g_mean[s$species == "Gentoo"], 5076.016260162602, tolerance = 1e-9)
  clean <- na_policy(read_penguins(penguins_csv()))
  adelie <- clean$flipper_length_mm[clean$species == "Adelie"]
  expect_equal(s$flipper_length_mm_sd[s$species == "Adelie"], stats::sd(adelie), tolerance = 1e-12)
})

test_that("summary_json is a stable JSON document", {
  s <- summarise_by_species(na_policy(read_penguins(penguins_csv())))
  j <- jsonlite::fromJSON(summary_json(s))
  expect_equal(names(j), "species")
  expect_equal(names(j$species), c("Adelie", "Chinstrap", "Gentoo"))
  expect_equal(j$species$Gentoo$n, 123)
  expect_equal(j$species$Gentoo$body_mass_g$mean, 5076.016260162602, tolerance = 1e-9)
})

test_that("summary matches the committed golden within 1e-9", {
  s <- summarise_by_species(na_policy(read_penguins(penguins_csv())))
  golden <- jsonlite::fromJSON(file.path(dirname(dirname(penguins_csv())), "golden", "p1.json"))
  got <- jsonlite::fromJSON(summary_json(s))
  expect_equal(got, golden, tolerance = 1e-9)
})
