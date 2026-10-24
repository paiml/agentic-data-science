test_that("every example prints its contract line", {
  root <- Sys.getenv("ADS_ROOT", unset = normalizePath(file.path("..", "..", "..", "..")))
  ex <- list.files(file.path(root, "r", "agenticds", "inst", "examples"), full.names = TRUE)
  expect_equal(length(ex), 8L)
  old <- setwd(root)
  on.exit(setwd(old))
  for (d in ex) {
    out <- utils::capture.output(source(file.path(d, "run.R"), local = new.env()))
    expect_true(any(grepl("^contract: ads-r-p[1-4] .* OK$", out)), info = basename(d))
  }
})
