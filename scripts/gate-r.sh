#!/usr/bin/env bash
# R gate: covr line coverage must be exactly 100, lintr zero lints, styler no diff.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
export ADS_ROOT="$root"
[ -z "${ADS_RLIB:-}" ] || export R_LIBS="$ADS_RLIB"
[ "${CI:-}" != true ] || [ -n "${ADS_RLIB:-}" ] || { echo "gate-r: ADS_RLIB unset in CI"; exit 1; }
cd "$root/r/agenticds"
Rscript -e '
if (identical(Sys.getenv("CI"), "true")) stopifnot(setequal(normalizePath(.libPaths()), normalizePath(c(Sys.getenv("ADS_RLIB"), .Library))))
cov <- covr::package_coverage(".")
p <- covr::percent_coverage(cov)
cat("covr:", p, "\n")
print(covr::zero_coverage(cov))
if (!isTRUE(p == 100)) quit(status = 1)
# Measured figure for pmat quality-gate (which parses no R); untracked, rewritten every run.
dir.create(file.path("..", "..", ".pmat-metrics"), showWarnings = FALSE)
jsonlite::write_json(
  list(
    coverage = p, tool = "covr",
    git_hash = system2("git", c("rev-parse", "HEAD"), stdout = TRUE),
    generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  ),
  file.path("..", "..", ".pmat-metrics", "coverage.json"), auto_unbox = TRUE, digits = NA
)
l <- lintr::lint_package(".")
cat("lintr:", length(l), "lints\n")
if (length(l) > 0) { print(l); quit(status = 1) }
d <- styler::style_pkg(".", dry = "on")
ch <- Filter(function(x) isTRUE(x$changed), split(d, seq_len(nrow(d))))
cat("styler: changed", length(ch), "files\n")
if (length(ch) > 0) quit(status = 1)
'
echo "gate-r OK"
