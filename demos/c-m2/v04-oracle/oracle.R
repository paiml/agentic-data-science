# two routes to the same line: normal equations vs parsnip
library(parsnip)
d <- na.omit(readr::read_csv("datasets/penguins/penguins.csv", show_col_types = FALSE))
X <- cbind(1, d$flipper_length_mm); y <- d$body_mass_g
beta <- solve(t(X) %*% X, t(X) %*% y)
fit <- linear_reg() |> fit(body_mass_g ~ flipper_length_mm, data = d)
coefs <- tibble::tibble(route = c("closed", "parsnip"),
  b0 = c(beta[1], coef(fit$fit)[1]), b1 = c(beta[2], coef(fit$fit)[2]))
coefs
ok <- all.equal(beta[, 1], coef(fit$fit), check.attributes = FALSE)
cat(cli::col_green(cli::style_bold(ok)), "\n")
