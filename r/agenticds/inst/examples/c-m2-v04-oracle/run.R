# C-M2 video 4: closed form vs parsnip, two independent routes.
# Usage (from the repo root): source("<this file>")
library(agenticds)
d <- na_policy(read_penguins("datasets/penguins/penguins.csv"))
beta <- ols_closed_form(d$flipper_length_mm, d$body_mass_g)
fit <- parsnip::fit(
  parsnip::set_engine(parsnip::linear_reg(), "lm"),
  body_mass_g ~ flipper_length_mm,
  data = d
)
coefs <- rbind(
  closed_form = unname(beta),
  parsnip = unname(coef(fit$fit))
)
colnames(coefs) <- c("intercept", "slope")
print(round(coefs, 4))
ok <- all.equal(coefs[1, ], coefs[2, ], tolerance = 1e-8)
print(ok)
stopifnot(isTRUE(ok))
verdict(
  "contract: ads-r-p2 solve() closed form == parsnip linear_reg OK"
)
