# the ticket's oracle: golden/p1.json must agree with the raw data
library(agenticds)

want <- strsplit(readLines("datasets/penguins/SHA256SUMS")[1], " +")[[1]]
got <- unname(tools::sha256sum("datasets/penguins/penguins.csv"))
cat(sprintf("penguins.csv: %s\n", if (identical(got, want[1])) "OK" else "FAILED"))
stopifnot(identical(got, want[1]))

g <- jsonlite::fromJSON("datasets/golden/p1.json")
raw <- read_penguins("datasets/penguins/penguins.csv")
d <- na_policy(raw)

cat(sprintf("raw rows %d, no measurements %d, clean rows %d\n",
  nrow(raw), nrow(raw) - nrow(d), nrow(d)))

ns <- vapply(g$species, function(s) s$n, numeric(1))
print(ns)
cat(sprintf("golden n sums to %d\n", sum(ns)))

ok <- identical(as.integer(ns), as.integer(table(d$species)[names(ns)])) &&
  sum(ns) == nrow(d) &&
  nrow(raw) == 344L &&
  nrow(d) == 342L
stopifnot(ok)
cat(cli::col_green(cli::style_bold("contract: ads-r-p1 ticket (344 -> 342) OK")), fill = TRUE)
