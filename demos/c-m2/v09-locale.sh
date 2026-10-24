#!/usr/bin/env bash
# shellcheck disable=SC2016
# C-M2 video 9: a sort-based split moves with the locale; the row-index folds do not
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
Rscript -e 'ids <- c("b1", "A2", "a3", "B4", "c5", "C6")
cat("sort-based fold order under", Sys.getlocale("LC_COLLATE"), ":", order(ids), "\n")'
bad_c="$(LC_ALL=C Rscript -e 'cat(order(c("b1", "A2", "a3", "B4", "c5", "C6")))')"
bad_u="$(LC_ALL=en_US.utf8 Rscript -e 'cat(order(c("b1", "A2", "a3", "B4", "c5", "C6")))')"
echo "sort-based order  C: $bad_c   en_US: $bad_u"
[ "$bad_c" != "$bad_u" ]
cvrun='library(agenticds); d <- na_policy(read_penguins("datasets/penguins/penguins.csv")); f <- read_folds("datasets/fixtures/folds.csv"); cat(Sys.getlocale("LC_COLLATE"), sprintf("%.17g", cv_rmse(d, f, TRUE)), "\n")'
out_c="$(LC_ALL=C Rscript -e "$cvrun")"
out_u="$(LC_ALL=en_US.utf8 Rscript -e "$cvrun")"
echo "row-index folds   C: $out_c"
echo "row-index folds   en_US: $out_u"
[ "${out_c%% *}" = "C" ] && [ "${out_u%% *}" = "en_US.utf8" ]
[ "${out_c#* }" = "${out_u#* }" ]
echo "contract: c-m2 row-index folds identical across locales OK"
