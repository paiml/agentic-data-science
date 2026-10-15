#!/usr/bin/env bash
# R gate: covr line coverage must be exactly 100, lintr zero lints, styler no diff.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
export ADS_ROOT="$root"
[ -z "${ADS_RLIB:-}" ] || export R_LIBS="$ADS_RLIB"
cd "$root/r/agenticds"
Rscript -e '
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
echo "gate-r OK"
