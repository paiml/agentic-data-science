#!/usr/bin/env bash
# shellcheck disable=SC2016
# C-M1 video 9: a malformed number becomes a reported parse problem, never a silent string
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
out="$(mktemp -d)"
trap 'rm -rf -- "${out:?}"' EXIT
head -n 1 datasets/penguins/penguins.csv > "$out/bad.csv"
echo "Adelie,Torgersen,39.1,18.7,181,heavy,male,2007" >> "$out/bad.csv"
echo "Adelie,Torgersen,39.5,17.4,186,3800,female,2007" >> "$out/bad.csv"
Rscript -e 'library(agenticds)
d <- read_penguins(commandArgs(TRUE)[1])
print(d[, c("species", "body_mass_g")]); print(readr::problems(d)[, c("row", "col", "expected", "actual")])
stopifnot(is.numeric(d$body_mass_g), is.na(d$body_mass_g[1]), nrow(readr::problems(d)) == 1L, nrow(na_policy(d)) == 1L)
cat("contract: c-m1 malformed number reported and dropped by the policy OK\n")' "$out/bad.csv"
