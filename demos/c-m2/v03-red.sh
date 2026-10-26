#!/usr/bin/env bash
# shellcheck disable=SC2016
# C-M2 video 3: break the slope in a scratch copy; the named oracle test goes red
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
scratch="$(mktemp -d)"
trap 'rm -rf -- "${scratch:?}"; rm -rf -- "${DEMO_LIB:?}"' EXIT
cp -r r/agenticds "$scratch/pkg"
cp -r datasets "$scratch/datasets"
run_tests='library(testthat)
r <- as.data.frame(test_dir(file.path(Sys.getenv("SCRATCH"), "pkg", "tests", "testthat"), filter = "p2", package = "agenticds", load_package = "source", reporter = "silent", stop_on_failure = FALSE))
cat("passed:", sum(r$passed), " failed:", sum(r$failed), " errored:", sum(r$error), "\n")
print(r[r$failed > 0 | r$error, "test"])
r'
echo "== baseline copy, before the change"
SCRATCH="$scratch" ADS_ROOT="$scratch" Rscript -e "r <- {$run_tests}; stopifnot(sum(r\$failed) == 0, sum(r\$error) == 0)"
sed -i "s/slope = b\[\[2\]\])/slope = b[[2]] + 1)/" "$scratch/pkg/R/p2.R"
echo "== change: slope = b[[2]] + 1"
grep -n "slope = b\[\[2\]\] + 1" "$scratch/pkg/R/p2.R"
SCRATCH="$scratch" ADS_ROOT="$scratch" Rscript -e "r <- {$run_tests}; stopifnot(sum(r\$failed) > 0, sum(r\$error) == 0, any(grepl('ols', r\$test[r\$failed > 0])))
cat('contract: c-m2 broken slope is caught by the ols oracle test OK\n')"
