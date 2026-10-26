#!/usr/bin/env bash
# R gate: covr line coverage must be exactly 100, lintr zero lints, styler no diff;
# scene projects under courses/C-r get lintr + styler + their tests too.
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
l <- lintr::lint_package(".")
cat("lintr:", length(l), "lints\n")
if (length(l) > 0) { print(l); quit(status = 1) }
d <- styler::style_pkg(".", dry = "on")
ch <- Filter(function(x) isTRUE(x$changed), split(d, seq_len(nrow(d))))
cat("styler: changed", length(ch), "files\n")
if (length(ch) > 0) quit(status = 1)
'
n=0
for p in "$root"/courses/C-r/*/scenes/*.d/project; do
  [ -d "$p" ] || continue
  n=$((n + 1))
  (cd "$p" && Rscript -e '
l <- lintr::lint_dir(".")
cat("lintr", basename(getwd()), length(l), "lints\n")
if (length(l) > 0) { print(l); quit(status = 1) }
d <- styler::style_dir(".", dry = "on")
if (any(d$changed)) { print(d[d$changed, ]); quit(status = 1) }
' && Rscript tests/testthat.R)
done
[ "$n" -ge 1 ] || { echo "FAIL gate-r: no scene project found"; exit 1; }
echo "gate-r OK"
