#!/usr/bin/env bash
# shellcheck disable=SC2016
# C-M2 video 2: closed-form OLS, slope and R2 computed
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
Rscript -e 'library(agenticds)
d <- na_policy(read_penguins("datasets/penguins/penguins.csv"))
b <- ols_closed_form(d$flipper_length_mm, d$body_mass_g)
print(b)
m1 <- agenticds:::regression_metrics(d$body_mass_g, b[["intercept"]] + b[["slope"]] * d$flipper_length_mm)
cat(sprintf("slope %.2f g/mm   R2 line %.3f\n", b[["slope"]], m1$r2))
m2 <- agenticds:::regression_metrics(d$body_mass_g, predict(lm(body_mass_g ~ flipper_length_mm + species, d), d))
cat(sprintf("R2 with species %.3f\n", m2$r2))
g <- jsonlite::fromJSON("datasets/golden/p2.json")
stopifnot(isTRUE(abs(m1$r2 - g$metrics$ols$r2) < 1e-9), isTRUE(abs(m2$r2 - g$metrics$species$r2) < 1e-9), isTRUE(m2$r2 > m1$r2))
cat("contract: c-m2 slope and R2 computed, match golden OK\n")'
