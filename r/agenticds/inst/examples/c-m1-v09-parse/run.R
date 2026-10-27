# C-M1 video 9: a malformed number is reported, never kept silently.
# Run from the repo root: source("<this file>")
library(agenticds)
csv <- file.path("datasets", "penguins", "penguins.csv")
bad <- tempfile(fileext = ".csv")
writeLines(c(
  readLines(csv, n = 1),
  "Adelie,Torgersen,39.1,18.7,181,heavy,male,2007",
  "Adelie,Torgersen,39.5,17.4,186,3800,female,2007"
), bad)
warned <- tryCatch(
  read_penguins(bad), warning = function(w) conditionMessage(w)
)
cat("warning:", sub(", call.*", "", warned), "\n")
d <- suppressWarnings(read_penguins(bad))
print(d[, c("species", "body_mass_g")])
p <- readr::problems(d)
print(p[, c("row", "col", "expected", "actual")])
stopifnot(is.numeric(d$body_mass_g), is.na(d$body_mass_g[1]))
stopifnot(is.character(warned), nrow(p) == 1L)
stopifnot(nrow(na_policy(d)) == 1L)
verdict("contract: ads-r-p1 bad number reported, dropped OK")
