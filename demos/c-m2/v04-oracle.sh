#!/usr/bin/env bash
# shellcheck disable=SC2016
# C-M2 video 4: closed form vs parsnip linear_reg, two independent routes
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
Rscript -e 'library(agenticds)
d <- na_policy(read_penguins("datasets/penguins/penguins.csv"))
cf <- ols_closed_form(d$flipper_length_mm, d$body_mass_g)
fit <- parsnip::fit(parsnip::set_engine(parsnip::linear_reg(), "lm"), body_mass_g ~ flipper_length_mm, data = d)
pn <- unname(fit$fit$coefficients)
print(rbind(closed_form = unname(cf), parsnip = pn))
stopifnot(isTRUE(all.equal(unname(cf), pn, tolerance = 1e-8)))
cat("contract: c-m2 closed form == parsnip linear_reg OK\n")'
