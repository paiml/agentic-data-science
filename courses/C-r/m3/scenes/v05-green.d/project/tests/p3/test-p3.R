root <- normalizePath(testthat::test_path("..", ".."))
h <- source(file.path(root, "R", "helpers.R"))$value
data_file <- function(name) file.path(root, "data", name)
clean <- function() h$load_clean(data_file("penguins.csv"))
golden <- jsonlite::fromJSON(data_file("p3.json"))

test_that("read_split and read_centroids load the fixtures", {
  s <- h$read_split(data_file("split.csv"))
  expect_equal(table(s)[["test"]], 85L)
  expect_equal(length(s), 342L)
  cen <- h$read_centroids(data_file("centroids.csv"))
  expect_equal(dim(cen), c(3L, 4L))
  expect_equal(colnames(cen), h$feats)
})

test_that("confusion and accuracy are exact counts", {
  truth <- factor(c("a", "a", "b", "b"), levels = c("a", "b"))
  pred <- factor(c("a", "b", "b", "b"), levels = c("a", "b"))
  cm <- table(truth = truth, pred = pred)
  expect_equal(as.vector(cm), c(1L, 0L, 1L, 2L))
  expect_equal(mean(truth == pred), 0.75)
})

test_that("the species tree classifies the fixed test split", {
  d <- clean()
  s <- h$read_split(data_file("split.csv"))
  fit <- h$fit_species_clf(d[s == "train", ])
  pred <- h$predict_species_clf(fit, d[s == "test", ])
  truth <- factor(d$species[s == "test"], levels = levels(pred))
  expect_equal(length(pred), 85L)
  expect_gt(mean(truth == pred), 0.9)
  expect_equal(levels(pred), c("Adelie", "Chinstrap", "Gentoo"))
})

test_that("kmeans_fixed matches stats::kmeans Lloyd", {
  d <- clean()
  cen <- h$read_centroids(data_file("centroids.csv"))
  km <- h$kmeans_fixed(d, cen)
  z <- scale(as.matrix(d[, h$feats]))
  zc <- scale(
    cen,
    center = attr(z, "scaled:center"),
    scale = attr(z, "scaled:scale")
  )
  ref <- stats::kmeans(z, zc, algorithm = "Lloyd", iter.max = 100)
  expect_equal(km$cluster, unname(ref$cluster))
  expect_equal(km$objective, ref$tot.withinss, tolerance = 1e-6)
  expect_equal(dim(km$centers), c(3L, 4L))
})

test_that("kmeans_fixed keeps the centroid of an emptied cluster", {
  d <- tibble::tibble(
    bill_length_mm = c(0, 1), bill_depth_mm = c(0, 1),
    flipper_length_mm = c(0, 1), body_mass_g = c(0, 1)
  )
  cen <- rbind(rep(0, 4), rep(1, 4), rep(100, 4))
  colnames(cen) <- h$feats
  km <- h$kmeans_fixed(d, cen)
  expect_equal(km$cluster, c(1L, 2L))
  expect_equal(unname(km$centers[3, ]), rep(100, 4))
})

test_that("the p3 results match the committed golden file", {
  d <- clean()
  s <- h$read_split(data_file("split.csv"))
  fit <- h$fit_species_clf(d[s == "train", ])
  pred <- h$predict_species_clf(fit, d[s == "test", ])
  truth <- factor(d$species[s == "test"], levels = levels(pred))
  cen <- h$read_centroids(data_file("centroids.csv"))
  km <- h$kmeans_fixed(d, cen)
  expect_lt(abs(mean(truth == pred) - golden$accuracy), 0.005)
  cm <- unname(unclass(table(truth = truth, pred = pred)))
  expect_equal(sum(cm != golden$confusion), 0L)
  expect_lt(abs(km$objective - golden$kmeans$objective), 1e-6)
  expect_equal(
    tabulate(km$cluster, nbins = 3),
    as.integer(golden$kmeans$cluster_sizes)
  )
})
