# v01 ticket: the oracle (golden counts) vs the raw data
h <- new.env()
sys.source("R/helpers.R", envir = h)

run_scene <- function() {
  stopifnot(h$check_sums("data"))
  golden <- jsonlite::fromJSON("data/p1.json")
  raw <- h$read_penguins("data/penguins.csv")
  clean <- h$na_policy(raw)
  cat("rows", nrow(raw), "->", nrow(clean), "\n")
  want <- vapply(golden$species, \(s) s$n, 1)
  have <- h$count_species(clean)[names(want)]
  print(rbind(golden = want, data = have))
  ok <- all(want == have) && sum(want) == nrow(clean)
  h$verdict("contract: c-m1 oracle matches: ", ok)
}

if (sys.nframe() == 0) run_scene()
