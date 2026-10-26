# v04 profile: per-species n, mean, sd, checked by hand
h <- new.env()
sys.source("R/helpers.R", envir = h)

run_scene <- function() {
  stopifnot(h$check_sums("data"))
  gold <- jsonlite::fromJSON("data/p1.json")
  d <- h$na_policy(h$read_penguins("data/penguins.csv"))
  s <- h$summarise_by_species(d)
  m <- c("body_mass_g_mean", "body_mass_g_sd")
  print(as.data.frame(s[c("species", "n", m)]))
  x <- d$body_mass_g[d$species == "Gentoo"]
  ss <- sum((x - mean(x))^2)
  hand <- sqrt(ss / (length(x) - 1))
  pop <- sqrt(ss / length(x))
  cat("Gentoo sd: summarise", s$body_mass_g_sd[3], "\n")
  cat("n-1 by hand", hand, " n (population)", pop, "\n")
  gold_sd <- gold$species$Gentoo$body_mass_g$sd
  ok <- identical(s$n, c(151L, 68L, 123L)) &&
    abs(hand - gold_sd) < 0.005 && abs(hand - pop) > 1e-3
  h$verdict("contract: c-m1 151/68/123, sd n-1: ", ok)
}

if (sys.nframe() == 0) run_scene()
