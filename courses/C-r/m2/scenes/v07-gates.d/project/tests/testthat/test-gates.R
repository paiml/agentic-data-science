library(testthat)
root <- normalizePath(testthat::test_path("..", ".."))
repo <- Sys.getenv("ADS_ROOT")
if (!nzchar(repo)) repo <- file.path(root, "../../../../../..")
repo <- normalizePath(repo)
scene <- readLines(file.path(root, "R/gates.sh"))
pkg_r <- "r/agenticds/R/p1.R"

# Run the scene file as written, in a repo root, and return the
# live output, the shell status and the printed exit= values.
run_scene <- function(ads_root) {
  old <- setwd(ads_root)
  on.exit(setwd(old))
  out <- suppressWarnings(system2(
    "env", c("-u", "ADS_ROOT", "sh", file.path(root, "R/gates.sh")),
    stdout = TRUE, stderr = TRUE
  ))
  hits <- regmatches(out, regexpr("^exit=[0-9]+$", out))
  list(
    out = paste(out, collapse = "\n"),
    exits = as.integer(sub("exit=", "", hits))
  )
}

# A copy of the real repo that a test may damage, then deletes.
run_mutant <- function(path, line) {
  tmp <- tempfile("repo")
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))
  keep <- setdiff(dir(repo, all.files = TRUE, no.. = TRUE), ".git")
  file.copy(file.path(repo, keep), tmp, recursive = TRUE)
  cat(line, file = file.path(tmp, path), sep = "\n", append = TRUE)
  # make gate-shacl lists files with git
  system2("git", c("-C", tmp, "init", "-q"))
  system2("git", c("-C", tmp, "add", "-A"))
  run_scene(tmp)
}

test_that("the scene fits the screen, 25 lines of 59 columns", {
  expect_lte(length(scene), 25L)
  expect_lte(max(nchar(scene)), 59L)
})
test_that("each tool runs natively, nothing prints a verdict", {
  src <- paste(scene, collapse = "\n")
  expect_match(src, "covr::package_coverage", fixed = TRUE)
  expect_match(src, "lintr::lint_package", fixed = TRUE)
  expect_match(src, "styler::style_pkg", fixed = TRUE)
  bad <- "capture.output|quiet|/dev/null|writeLines| \\| |passed"
  expect_false(grepl(bad, src))
  expect_equal(sum(grepl("^echo .exit=", scene)), 4L)
  expect_match(src, "make gate-shacl", fixed = TRUE)
})
test_that("the real package passes, every tool exits 0", {
  res <- run_scene(repo)
  expect_equal(res$exits, c(0L, 0L, 0L, 0L))
  expect_match(res$out, "sh:conforms +true")
  expect_match(res$out, "Coverage: 100.00%")
  expect_match(res$out, "No lints found")
})
test_that("an untested function fails only the coverage gate", {
  res <- run_mutant(
    pkg_r, c("unused <- function(x) {", "  x + 1", "}")
  )
  expect_equal(res$exits[2], 1L)
  expect_false(grepl("Coverage: 100.00%", res$out, fixed = TRUE))
})
test_that("a lint fails the lint gate", {
  res <- run_mutant(pkg_r, "lint_me <- c(1,2)")
  expect_equal(res$exits[3], 1L)
  expect_match(res$out, "comma")
})
test_that("an unstyled file fails the style gate", {
  res <- run_mutant(pkg_r, "styled <-   1")
  expect_equal(res$exits[4], 1L)
})
test_that("a shape violation fails the SHACL gate", {
  res <- run_mutant(
    "ontology/shapes/dataset.shape.ttl",
    paste(
      "ads:NeedsLicense a sh:NodeShape ;",
      "sh:targetClass ads:Dataset ;",
      "sh:property [ sh:path ads:license ; sh:minCount 1 ] ."
    )
  )
  expect_gt(res$exits[1], 0L)
  expect_match(res$out, "FAIL")
})
