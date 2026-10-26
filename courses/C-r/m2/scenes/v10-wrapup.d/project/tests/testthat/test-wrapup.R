library(testthat)
root <- normalizePath(testthat::test_path("..", ".."))
old <- setwd(root)
source("R/helpers.R")
source("R/wrapup.R")
scene <- readLines("R/wrapup.R")
scene_lines <- length(scene)
setwd(old)
work <- tempfile("scene")
dir.create(work)
file.copy(dir(root, full.names = TRUE), work, recursive = TRUE)
old <- setwd(work)
out <- utils::capture.output(ok <- run_scene())
txt <- paste(out, collapse = " ")
g <- jsonlite::fromJSON("data/p2.json")
d <- load_clean("data/penguins.csv")

test_that("the scene file fits the screen, 25 lines or fewer", {
  expect_lte(scene_lines, 25L)
  expect_lte(max(nchar(scene)), 59L)
})
test_that("drop_na keeps 342 rows (D14)", {
  expect_equal(nrow(d), 342L)
})
test_that("each example prints its own contract line", {
  for (e in c("c-m2-p2-ols", "c-m2-p2-cv")) {
    run <- file.path("examples", e, "run.R")
    o <- utils::capture.output(source(run, local = new.env()))
    expect_match(o[length(o)], "^contract: ads-r-p2 .* OK$")
  }
})
test_that("the scene shows two OK contracts and reports TRUE", {
  expect_true(ok)
  expect_match(
    txt, "ads-r-p2 ols matches golden/p2.json OK",
    fixed = TRUE
  )
  expect_match(
    txt, "ads-r-p2 cv matches golden/p2.json OK",
    fixed = TRUE
  )
  expect_match(txt, "two contracts, both OK: TRUE")
})
test_that("a wrong golden stops the scene before any OK", {
  p <- "data/p2.json"
  keep <- readLines(p)
  on.exit(writeLines(keep, p))
  bad <- jsonlite::fromJSON(p)
  bad$cv_rmse$ols <- bad$cv_rmse$ols + 1
  jsonlite::write_json(bad, p, auto_unbox = TRUE, digits = NA)
  expect_error(utils::capture.output(run_scene()))
})
test_that("the golden CV RMSE is what the example checks", {
  f <- read_folds("data/folds.csv")
  expect_equal(cv_rmse(d, f), g$cv_rmse$ols, tolerance = 1e-8)
  expect_equal(
    cv_rmse(d, f, species = TRUE), g$cv_rmse$species,
    tolerance = 1e-8
  )
})
test_that("the closed form matches the golden OLS", {
  b <- ols_closed_form(d$flipper_length_mm, d$body_mass_g)
  expect_equal(b[["slope"]], g$ols$slope, tolerance = 1e-8)
})
test_that("regression_metrics gives RMSE and R squared", {
  toy <- regression_metrics(c(1, 2, 3, 4), c(1, 2, 3, 6))
  expect_equal(toy$rmse, 1)
  expect_equal(toy$r2, 1 - 4 / 5)
})
test_that("read_folds returns one fold per row", {
  expect_length(read_folds("data/folds.csv"), 342L)
})
test_that("verdict returns and prints a failure as FALSE", {
  res <- utils::capture.output(r <- verdict("x", FALSE))
  expect_false(r)
  expect_match(res, "x: FALSE")
})
setwd(old)
