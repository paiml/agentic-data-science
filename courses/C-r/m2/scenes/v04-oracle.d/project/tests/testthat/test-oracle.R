library(testthat)
root <- normalizePath(testthat::test_path("..", ".."))
if (!exists("run_scene")) {
  source(file.path(root, "R", "oracle.R"))
}
work <- tempfile("scene")
dir.create(file.path(work, "data"), recursive = TRUE)
csv <- file.path(root, "data", "penguins.csv")
stopifnot(file.copy(csv, file.path(work, "data")))
withr::local_dir(work)
withr::defer(unlink(work, recursive = TRUE))
d <- load_penguins("data/penguins.csv")
b <- fit_line(d)
verdict <- utils::capture.output(ok <- run_scene())

test_that("drop_na keeps 342 rows (D14)", {
  expect_equal(nrow(d), 342L)
})
test_that("parsnip intercept matches the pv postcondition", {
  expect_equal(b[[1]], -5780.83, tolerance = 1e-3)
})
test_that("parsnip slope matches the pv postcondition", {
  expect_equal(b[[2]], 49.69, tolerance = 1e-3)
})
test_that("parsnip equals the normal-equation oracle within 1e-8", {
  x <- cbind(1, d$flipper_length_mm)
  beta <- solve(crossprod(x), crossprod(x, d$body_mass_g))
  expect_equal(unname(b), unname(beta[, 1]), tolerance = 1e-8)
})
test_that("the scatter plus fitted line PNG is written", {
  expect_gt(file.size(file.path(work, "plot.png")), 10000)
  p <- save_plot(d, tempfile(fileext = ".png"))
  geoms <- vapply(p$layers, function(l) class(l$geom)[1], "")
  expect_equal(unname(geoms), c("GeomPoint", "GeomSmooth"))
})
test_that("the scene reports TRUE and prints the 342-row verdict", {
  expect_true(ok)
  expect_match(
    paste(verdict, collapse = " "),
    "342 rows, slope 49.69: TRUE"
  )
})
