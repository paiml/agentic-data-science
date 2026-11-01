root <- Sys.getenv(
  "ADS_ROOT",
  unset = normalizePath(file.path("..", "..", "..", ".."))
)
ex <- list.files(
  file.path(root, "r", "agenticds", "inst", "examples"),
  full.names = TRUE
)

nested <- paste(
  "eval\\(parse|test_file|test_dir|file_coverage",
  "package_coverage|load_all|source\\(",
  sep = "|"
)
# code lines only: a "source(" in a header comment is no nesting
reloads <- function(d) {
  code <- readLines(file.path(d, "run.R"))
  any(grepl(nested, code[!grepl("^\\s*#", code)]))
}

test_that("every example directory holds a run.R", {
  expect_gte(length(ex), 8L)
  expect_true(all(file.exists(file.path(ex, "run.R"))))
})

for (d in ex) {
  test_that(paste(basename(d), "ends with its contract verdict"), {
    # under covr, skip scenes that reload, re-source or nest
    # test runs: they would alter the code being measured
    skip_if(
      identical(Sys.getenv("R_COVR"), "true") && reloads(d)
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
