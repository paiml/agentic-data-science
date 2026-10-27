root <- Sys.getenv(
  "ADS_ROOT",
  unset = normalizePath(file.path("..", "..", "..", ".."))
)
ex <- list.files(
  file.path(root, "r", "agenticds", "inst", "examples"),
  full.names = TRUE
)

test_that("every example directory holds a run.R", {
  expect_gte(length(ex), 8L)
  expect_true(all(file.exists(file.path(ex, "run.R"))))
})

for (d in ex) {
  test_that(paste(basename(d), "ends with its contract verdict"), {
    # a gates scene runs covr itself, which cannot nest inside covr
    skip_if(
      identical(Sys.getenv("R_COVR"), "true") &&
        grepl("-gates$", basename(d))
    )
    old <- setwd(root)
    on.exit(setwd(old))
    out <- utils::capture.output(
      source(file.path(d, "run.R"), local = new.env())
    )
    expect_gt(length(out), 0L)
    expect_match(
      out[[length(out)]],
      "^contract: ads-r-p[1-4] .* OK$"
    )
  })
}
