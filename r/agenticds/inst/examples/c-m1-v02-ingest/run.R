# C-M1 video 2: typed ingest and the NA policy.
# Run from the repo root: source("<this file>")
library(agenticds)
raw <- read_penguins("datasets/penguins/penguins.csv")
clean <- na_policy(raw)
cat("Column types:\n")
print(vapply(raw, function(x) class(x)[1], character(1)))
cat("Missing values per column (raw):\n")
print(colSums(is.na(raw)))
sex_na <- sum(is.na(clean$sex))
cat(sprintf(
  "rows %d -> %d; sex still missing in %d clean rows\n",
  nrow(raw), nrow(clean), sex_na
))
stopifnot(
  nrow(raw) == 344L, nrow(clean) == 342L, sex_na == 9L,
  is.numeric(raw$body_mass_g), is.integer(raw$year)
)
verdict("contract: ads-r-p1 typed ingest, sex NA kept OK")
