# v09 parse: a malformed number is reported, never silent
h <- new.env()
sys.source("R/helpers.R", envir = h)

run_scene <- function() {
  path <- tempfile(fileext = ".csv")
  rows <- c("Adelie,NA", "Adelie,heavy", "Adelie,3800")
  writeLines(c("species,body_mass_g", rows), path)
  raw <- readr::read_csv(path, col_types = "cc", na = "NA")
  good <- grepl("^[0-9.]+$", raw$body_mass_g)
  bad <- !good & !is.na(raw$body_mass_g)
  print(tibble::tibble(
    row = which(bad), expected = "a double",
    actual = raw$body_mass_g[bad]
  ))
  raw$body_mass_g[!good] <- NA
  raw$body_mass_g <- as.numeric(raw$body_mass_g)
  kept <- raw[!is.na(raw$body_mass_g), ]
  print(kept)
  ok <- sum(bad) == 1 && which(bad) == 2 && nrow(kept) == 1
  h$verdict("contract: c-m1 bad number reported: ", ok)
}

if (sys.nframe() == 0) run_scene()
