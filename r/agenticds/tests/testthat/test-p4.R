root_dir <- function() {
  Sys.getenv("ADS_ROOT", unset = normalizePath(file.path("..", "..", "..", "..")))
}
wine_path <- function(color) {
  file.path(root_dir(), "datasets", "wine-quality", paste0("winequality-", color, ".csv"))
}
wine_df <- function() agenticds::read_wine(wine_path("red"), wine_path("white"))

test_that("read_wine binds both colours with typed columns", {
  df <- wine_df()
  expect_equal(nrow(df), 6497L)
  expect_equal(table(df$color)[["red"]], 1599L)
  expect_equal(table(df$color)[["white"]], 4898L)
  expect_true(is.integer(df$quality))
})

test_that("validate_wine accepts the data and rejects each defect", {
  df <- wine_df()
  expect_identical(validate_wine(df), df)
  na_df <- df
  na_df$alcohol[1] <- NA
  expect_error(validate_wine(na_df), "missing")
  bad_q <- df
  bad_q$quality[1] <- 11L
  expect_error(validate_wine(bad_q), "quality")
  bad_c <- df
  bad_c$color[1] <- "rose"
  expect_error(validate_wine(bad_c), "color")
})

test_that("split_wine sends every fifth row to test", {
  df <- wine_df()
  s <- split_wine(df)
  expect_equal(nrow(s$test), 1299L)
  expect_equal(nrow(s$train), 5198L)
  expect_equal(s$test$alcohol[1], df$alcohol[5])
})

test_that("pipeline_wine scores a linear quality model on the held-out rows", {
  res <- pipeline_wine(wine_path("red"), wine_path("white"))
  s <- split_wine(wine_df())
  fit <- stats::lm(quality ~ ., data = s$train)
  pred <- stats::predict(fit, newdata = s$test)
  expect_equal(res$rmse, sqrt(mean((s$test$quality - pred)^2)), tolerance = 1e-6)
  expect_equal(res$n_rows, 6497L)
  expect_equal(names(res$mean_quality_by_color), c("red", "white"))
})

test_that("dplyr and data.table aggregates agree and bench_wine times both", {
  df <- wine_df()
  a <- aggregate_dplyr(df)
  b <- aggregate_data_table(df)
  expect_equal(a$color, b$color)
  expect_equal(a$mean_quality, b$mean_quality, tolerance = 1e-12)
  expect_equal(a$n, b$n)
  bench <- bench_wine(df, reps = 2L)
  expect_equal(sort(bench$engine), c("data.table", "dplyr"))
  expect_true(all(bench$seconds >= 0))
})

test_that("write_golden and report_ttl write the artifacts", {
  res <- pipeline_wine(wine_path("red"), wine_path("white"))
  tmp <- withr::local_tempdir()
  gold <- file.path(tmp, "p4.json")
  write_golden(res, gold)
  expect_equal(jsonlite::fromJSON(gold)$n_rows, 6497)
  ttl <- file.path(tmp, "artifact.ttl")
  report_ttl(res, ttl)
  txt <- paste(readLines(ttl), collapse = "\n")
  expect_match(txt, "a ads:Artifact")
  expect_match(txt, "ads:schemaVersion \"1\"")
})

test_that("p4 summary matches the committed golden", {
  golden <- jsonlite::fromJSON(file.path(root_dir(), "datasets", "golden", "p4.json"))
  res <- pipeline_wine(wine_path("red"), wine_path("white"))
  tmp <- withr::local_tempdir()
  write_golden(res, file.path(tmp, "p4.json"))
  got <- jsonlite::fromJSON(file.path(tmp, "p4.json"))
  expect_equal(got, golden, tolerance = 1e-6)
})
