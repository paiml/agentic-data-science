# P2 (a): closed-form OLS. Usage: ADS_ROOT=/path/to/repo Rscript run.R
root <- Sys.getenv("ADS_ROOT", unset = ".")
library(agenticds)
d <- na_policy(read_penguins(file.path(root, "datasets", "penguins", "penguins.csv")))
print(ols_closed_form(d$flipper_length_mm, d$body_mass_g))
