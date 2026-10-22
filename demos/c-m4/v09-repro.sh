#!/usr/bin/env bash
# shellcheck disable=SC2016
# C-M4 video 9: a sort-keyed split moves with the locale; the row-index split and the pipeline do not
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
ids='c("b1", "A2", "a3", "B4", "c5", "C6")'
bad_c="$(LC_ALL=C Rscript -e "cat(order($ids))")"
bad_u="$(LC_ALL=en_US.utf8 Rscript -e "cat(order($ids))")"
echo "sort-keyed order  C: $bad_c   en_US: $bad_u"
[ "$bad_c" != "$bad_u" ]
run='library(agenticds); r <- pipeline_wine("datasets/wine-quality/winequality-red.csv", "datasets/wine-quality/winequality-white.csv"); cat(Sys.getlocale("LC_COLLATE"), r$n_test, sprintf("%.17g", r$rmse), "\n")'
out_c="$(LC_ALL=C Rscript -e "$run")"
out_u="$(LC_ALL=en_US.utf8 Rscript -e "$run")"
echo "row-index split   C: $out_c"
echo "row-index split   en_US: $out_u"
[ "${out_c%% *}" = "C" ] && [ "${out_u%% *}" = "en_US.utf8" ]
[ "${out_c#* }" = "${out_u#* }" ]
echo "contract: c-m4 row-index split and rmse identical across locales that sort differently OK"
