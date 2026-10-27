# C-M1 video 1: the ticket's oracle against the data.
# Usage (from the repo root): Rscript run.R
library(agenticds)
dir <- file.path("datasets", "penguins")
csv <- file.path(dir, "penguins.csv")
want <- strsplit(readLines(file.path(dir, "SHA256SUMS")), " ")[[1]][1]
have <- strsplit(system2("sha256sum", csv, stdout = TRUE), " ")[[1]][1]
cat("penguins.csv:", if (have == want) "OK" else "FAILED", "\n")
golden <- jsonlite::fromJSON(file.path("datasets", "golden", "p1.json"))
raw <- read_penguins(csv)
clean <- na_policy(raw)
cat(sprintf(
  "raw rows %d, rows with no measurements %d, clean rows %d\n",
  nrow(raw), nrow(raw) - nrow(clean), nrow(clean)
))
n <- vapply(golden$species, function(s) s$n, numeric(1))
print(n)
cat(sprintf("golden n sums to %d\n", sum(n)))
stopifnot(
  have == want,
  identical(as.integer(n), as.integer(table(clean$species)[names(n)])),
  sum(n) == nrow(clean),
  nrow(raw) == 344L,
  nrow(clean) == 342L
)
verdict("contract: ads-r-p1 ticket oracle matches data 344 -> 342 OK")
