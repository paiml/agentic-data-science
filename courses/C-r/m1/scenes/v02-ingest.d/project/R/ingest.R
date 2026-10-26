# v02 ingest: typed columns, then the NA policy
h <- new.env()
sys.source("R/helpers.R", envir = h)

run_scene <- function() {
  stopifnot(h$check_sums("data"))
  gold <- jsonlite::fromJSON("data/p1.json")
  raw <- h$read_penguins("data/penguins.csv")
  print(vapply(raw, \(x) class(x)[1], ""))
  miss <- colSums(is.na(raw))
  print(miss[miss > 0])
  clean <- h$na_policy(raw)
  cat("rows", nrow(raw), "->", nrow(clean), "\n")
  sex_na <- sum(is.na(clean$sex))
  cat("sex still NA in", sex_na, "clean rows\n")
  want <- sum(vapply(gold$species, \(s) s$n, 1))
  ok <- nrow(clean) == want && sex_na == 9
  h$verdict("contract: c-m1 ingest 344 -> 342: ", ok)
}

if (sys.nframe() == 0) run_scene()
