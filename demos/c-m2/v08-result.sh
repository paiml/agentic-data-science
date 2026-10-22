#!/usr/bin/env bash
# shellcheck disable=SC2016
# C-M2 video 8: CV RMSE above in-sample RMSE, all computed
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
Rscript -e 'library(agenticds)
d <- na_policy(read_penguins("datasets/penguins/penguins.csv"))
f <- read_folds("datasets/fixtures/folds.csv")
y <- d$body_mass_g
b <- ols_closed_form(d$flipper_length_mm, y)
in_l <- agenticds:::regression_metrics(y, b[["intercept"]] + b[["slope"]] * d$flipper_length_mm)$rmse
in_s <- agenticds:::regression_metrics(y, predict(lm(body_mass_g ~ flipper_length_mm + species, d), d))$rmse
cv_l <- cv_rmse(d, f, FALSE); cv_s <- cv_rmse(d, f, TRUE)
cat(sprintf("in-sample  line %.1f  species %.1f\ncross-val  line %.1f  species %.1f\n", in_l, in_s, cv_l, cv_s))
cat(sprintf("species cuts CV error by %.1f g (%.1f%%)\n", cv_l - cv_s, 100 * (cv_l - cv_s) / cv_l))
stopifnot(cv_l > in_l, cv_s > in_s, cv_s < cv_l)
cat("contract: c-m2 cv above in-sample, species better OK\n")'
