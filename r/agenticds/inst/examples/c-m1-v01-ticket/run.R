# C-M1 video 1: the ticket's oracle against the data.
# Run from the repo root: source("<this file>")
library(agenticds)
dir <- file.path("datasets", "penguins")
csv <- file.path(dir, "penguins.csv")
sums <- readLines(file.path(dir, "SHA256SUMS"))
want <- strsplit(sums, " ")[[1]][1]
out <- system2("sha256sum", csv, stdout = TRUE)
have <- strsplit(out, " ")[[1]][1]
cat("penguins.csv:", if (have == want) "OK" else "FAILED", "\n")
golden <- jsonlite::fromJSON("datasets/golden/p1.json")
raw <- read_penguins(csv)
clean <- na_policy(raw)
cat(sprintf(
  "raw rows %d, rows with no measurements %d, clean rows %d\n",
  nrow(raw), nrow(raw) - nrow(clean), nrow(clean)
))
n <- vapply(golden$species, function(s) s$n, numeric(1))
print(n)
cat(sprintf("golden n sums to %d\n", sum(n)))
by_species <- as.integer(table(clean$species)[names(n)])
stopifnot(have == want, identical(as.integer(n), by_species))
stopifnot(sum(n) == nrow(clean), nrow(raw) == 344L)
verdict("contract: ads-r-p1 ticket oracle matches data OK")
