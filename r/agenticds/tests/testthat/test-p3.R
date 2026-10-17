root_dir <- function() {
  Sys.getenv("ADS_ROOT", unset = normalizePath(file.path("..", "..", "..", "..")))
}
clean_df <- function() {
  path <- file.path(root_dir(), "datasets", "penguins", "penguins.csv")
  agenticds::na_policy(agenticds::read_penguins(path))
}
fixture <- function(name) file.path(root_dir(), "datasets", "fixtures", name)
feats <- c("bill_length_mm", "bill_depth_mm", "flipper_length_mm", "body_mass_g")

test_that("read_split and read_centroids load the fixtures", {
  s <- read_split(fixture("split.csv"))
  expect_equal(table(s)[["test"]], 85L)
  expect_equal(length(s), 342L)
  cen <- read_centroids(fixture("centroids.csv"))
  expect_equal(dim(cen), c(3L, 4L))
  expect_equal(colnames(cen), feats)
})

test_that("confusion and accuracy are exact counts", {
  truth <- factor(c("a", "a", "b", "b"), levels = c("a", "b"))
  pred <- factor(c("a", "b", "b", "b"), levels = c("a", "b"))
  cm <- confusion(truth, pred)
  expect_equal(unname(cm), matrix(c(1L, 0L, 1L, 2L), 2, 2))
  expect_equal(accuracy(truth, pred), 0.75)
})

test_that("the species tree classifies the fixed test split", {
  df <- clean_df()
  s <- read_split(fixture("split.csv"))
  fit <- fit_species_clf(df[s == "train", ])
  pred <- predict_species_clf(fit, df[s == "test", ])
  truth <- factor(df$species[s == "test"], levels = levels(pred))
  expect_equal(sum(confusion(truth, pred)), 85L)
  expect_gt(accuracy(truth, pred), 0.9)
  expect_equal(levels(pred), c("Adelie", "Chinstrap", "Gentoo"))
})

test_that("kmeans_fixed matches stats::kmeans Lloyd from the same centroids", {
  df <- clean_df()
  cen <- read_centroids(fixture("centroids.csv"))
  km <- kmeans_fixed(df, cen)
  z <- scale(as.matrix(df[, feats]))
  zc <- scale(cen, center = attr(z, "scaled:center"), scale = attr(z, "scaled:scale"))
  ref <- stats::kmeans(z, centers = zc, algorithm = "Lloyd", iter.max = 100)
  expect_equal(km$cluster, unname(ref$cluster))
  expect_equal(km$objective, ref$tot.withinss, tolerance = 1e-6)
  expect_equal(dim(km$centers), c(3L, 4L))
})

test_that("kmeans_fixed keeps the centroid of a cluster that ends up empty", {
  df <- tibble::tibble(
    bill_length_mm = c(0, 1), bill_depth_mm = c(0, 1),
    flipper_length_mm = c(0, 1), body_mass_g = c(0, 1)
  )
  cen <- rbind(rep(0, 4), rep(1, 4), rep(100, 4))
  colnames(cen) <- feats
  km <- kmeans_fixed(df, cen)
  expect_equal(km$cluster, c(1L, 2L))
  expect_equal(unname(km$centers[3, ]), rep(100, 4))
})

test_that("p3 summary matches the committed golden", {
  golden <- jsonlite::fromJSON(file.path(root_dir(), "datasets", "golden", "p3.json"))
  df <- clean_df()
  got <- jsonlite::fromJSON(p3_json(
    df, read_split(fixture("split.csv")),
    read_centroids(fixture("centroids.csv"))
  ))
  expect_equal(got$accuracy, golden$accuracy)
  expect_equal(got$confusion, golden$confusion)
  expect_equal(got$kmeans$objective, golden$kmeans$objective, tolerance = 1e-6)
  expect_equal(got$kmeans$cluster_sizes, golden$kmeans$cluster_sizes)
})
