# the ticket's oracle: golden/p1.json must agree with the raw data
# Usage: ADS_ROOT=/path/to/repo Rscript run.R
root <- Sys.getenv("ADS_ROOT", unset = ".")
library(agenticds)

pen <- file.path(root, "datasets", "penguins")
want <- strsplit(
  readLines(file.path(pen, "SHA256SUMS"))[1], " +"
)[[1]]
got <- strsplit(system2(
  "sha256sum", file.path(pen, "penguins.csv"), stdout = TRUE
), " +")[[1]][1]
ok_sha <- identical(got, want[1])
cat(sprintf(
  "penguins.csv: %s\n", if (ok_sha) "OK" else "FAILED"
))
stopifnot(ok_sha)

g <- jsonlite::fromJSON(
  file.path(root, "datasets", "golden", "p1.json")
)
raw <- read_penguins(file.path(pen, "penguins.csv"))
d <- na_policy(raw)

cat(sprintf(
  "raw rows %d, no measurements %d, clean rows %d\n",
  nrow(raw), nrow(raw) - nrow(d), nrow(d)
))

ns <- vapply(g$species, function(s) s$n, numeric(1))
print(ns)
cat(sprintf("golden n sums to %d\n", sum(ns)))

same <- identical(
  as.integer(ns), as.integer(table(d$species)[names(ns)])
)
ok <- same &&
  sum(ns) == nrow(d) &&
  nrow(raw) == 344L &&
  nrow(d) == 342L
stopifnot(ok)
cat(cli::col_green(cli::style_bold(
  "contract: ads-r-p1 ticket oracle (344 -> 342) OK"
)), fill = TRUE)
