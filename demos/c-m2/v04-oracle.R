# C-M2 video 4 (native R): the closed form against parsnip linear_reg, two independent routes.
# Run from the repo root: Rscript demos/c-m2/v04-oracle.R
.libPaths(c(Sys.getenv("ADS_RLIB"), .libPaths()))
options(cli.num_colors = 256L)
suppressMessages(pkgload::load_all("r/agenticds", quiet = TRUE))
d <- na_policy(read_penguins("datasets/penguins/penguins.csv"))
src <- c(
  "X <- cbind(1, d$flipper_length_mm)",
  "y <- d$body_mass_g",
  "beta <- solve(t(X) %*% X, t(X) %*% y)",
  "fit <- parsnip::fit(parsnip::set_engine(parsnip::linear_reg(), \"lm\"),",
  "                    body_mass_g ~ flipper_length_mm, data = d)",
  "coefs <- rbind(closed_form = c(beta), parsnip = unname(coef(fit$fit)))",
  "all.equal(coefs[1, ], coefs[2, ], tolerance = 1e-8)")
cat("\033[2J\033[H")
cat(cli::col_grey("# two routes to the same line: normal equations vs parsnip"), "\n\n", sep = "")
for (l in cli::code_highlight(src)) cat(cli::col_grey("> "), l, "\n", sep = "")
Sys.sleep(4)
cat("\n", cli::col_grey("# run"), "\n", sep = "")
eval(parse(text = src[1:6]))
for (r in rownames(coefs)) {
  cat(cli::col_cyan(sprintf("%-12s", r)), sprintf("%12.4f %12.4f", coefs[r, 1], coefs[r, 2]), "\n", sep = "")
}
Sys.sleep(1.5)
ok <- eval(parse(text = src[7]))
stopifnot(isTRUE(ok))
cat(cli::col_grey("> "), cli::code_highlight(src[7])[1], "\n", sep = "")
cat(cli::style_bold(cli::col_green("[1] TRUE")), "\n", sep = "")
Sys.sleep(3)
cat("contract: c-m2 closed form == parsnip linear_reg OK\n")
Sys.sleep(3.5)
