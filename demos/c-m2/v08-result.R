# C-M2 video 8 (native R): CV RMSE above in-sample RMSE, all computed.
source("demos/native-lib.R")
src <- c(
  "d <- na_policy(read_penguins(\"datasets/penguins/penguins.csv\"))",
  "f <- read_folds(\"datasets/fixtures/folds.csv\")",
  "b <- ols_closed_form(d$flipper_length_mm, d$body_mass_g)",
  "in_l <- regression_metrics(d$body_mass_g, b[[1]] + b[[2]] * d$flipper_length_mm)$rmse",
  "cv_l <- cv_rmse(d, f, FALSE); cv_s <- cv_rmse(d, f, TRUE)",
  "cv_l > in_l && cv_s < cv_l")
d <- na_policy(read_penguins("datasets/penguins/penguins.csv"))
f <- read_folds("datasets/fixtures/folds.csv")
b <- ols_closed_form(d$flipper_length_mm, d$body_mass_g)
in_l <- regression_metrics(d$body_mass_g, b[[1]] + b[[2]] * d$flipper_length_mm)$rmse
cv_l <- cv_rmse(d, f, FALSE)
cv_s <- cv_rmse(d, f, TRUE)
nat_show("cross-validated error sits above in-sample error; species helps", src)
nat_row("in-sample line", sprintf("%.1f g", in_l))
nat_row("cross-val line", sprintf("%.1f g", cv_l))
nat_row("cross-val spec.", sprintf("%.1f g  (%.1f g better)", cv_s, cv_l - cv_s))
nat_verdict(src[6], cv_l > in_l && cv_s < cv_l, "contract: c-m2 cv above in-sample, species better OK")
