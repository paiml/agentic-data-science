#!/usr/bin/env bash
# shellcheck disable=SC2016
# C-M4 video 9: the pipeline gives the same error to 17 digits in two locales
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
run='library(agenticds); r <- pipeline_wine("datasets/wine-quality/winequality-red.csv", "datasets/wine-quality/winequality-white.csv"); cat(Sys.getlocale("LC_COLLATE"), sprintf("%.17g", r$rmse), "\n")'
out_c="$(LC_ALL=C Rscript -e "$run")"
out_u="$(LC_ALL=en_US.utf8 Rscript -e "$run")"
echo "C:     $out_c"
echo "en_US: $out_u"
[ "${out_c%% *}" = "C" ] && [ "${out_u%% *}" = "en_US.utf8" ]
[ "${out_c#* }" = "${out_u#* }" ]
echo "contract: c-m4 rmse identical to 17 digits across locales OK"
