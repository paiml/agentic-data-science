#!/usr/bin/env bash
# shellcheck disable=SC2016
# C-M3 video 9: class order and tie-breaking do not depend on the locale
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
lc="$(LC_ALL=C Rscript -e 'cat(sort(c("a", "B", "b", "A")))')"
lu="$(LC_ALL=en_US.utf8 Rscript -e 'cat(sort(c("a", "B", "b", "A")))')"
echo "sort(a B b A)  C: $lc   en_US: $lu"
[ "$lc" != "$lu" ]
cvrun='library(agenticds); d <- na_policy(read_penguins("datasets/penguins/penguins.csv")); s <- read_split("datasets/fixtures/split.csv"); fit <- fit_species_clf(d[s == "train", ]); p <- predict_species_clf(fit, d[s == "test", ]); cat(Sys.getlocale("LC_COLLATE"), paste(levels(p), collapse = ","), sprintf("%.17g", accuracy(factor(d$species[s == "test"], levels = levels(p)), p)), "\n")'
out_c="$(LC_ALL=C Rscript -e "$cvrun")"
out_u="$(LC_ALL=en_US.utf8 Rscript -e "$cvrun")"
echo "C:     $out_c"
echo "en_US: $out_u"
[ "${out_c%% *}" = "C" ]
[ "${out_u%% *}" = "en_US.utf8" ]
[ "${out_c#* }" = "${out_u#* }" ]
echo "contract: c-m3 locales sort differently, classes and accuracy identical OK"
