root <- Sys.getenv(
  "ADS_ROOT",
  unset = normalizePath(file.path("..", "..", "..", ".."))
)
ex <- list.files(
  file.path(root, "r", "agenticds", "inst", "examples"),
  full.names = TRUE
)

test_that("there are nine examples", {
  expect_equal(length(ex), 9L)
})

for (d in ex) {
  test_that(paste(basename(d), "ends with its contract verdict"), {
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
