# C-M1 video 4: per-species n, mean and sd (n - 1 formula).
# Run from the repo root: source("<this file>")
library(agenticds)
clean <- na_policy(read_penguins("datasets/penguins/penguins.csv"))
s <- summarise_by_species(clean)
print(as.data.frame(
  s[, c("species", "n", "body_mass_g_mean", "body_mass_g_sd")]
))
x <- clean$body_mass_g[clean$species == "Gentoo"]
ss <- sum((x - mean(x))^2)
hand <- sqrt(ss / (length(x) - 1))
pop <- sqrt(ss / length(x))
gentoo <- s$body_mass_g_sd[s$species == "Gentoo"]
cat(sprintf(
  "Gentoo body mass sd: summarise %.6f, n-1 by hand %.6f, n %.6f\n",
  gentoo, hand, pop
))
stopifnot(s$n == c(151L, 68L, 123L))
stopifnot(isTRUE(all.equal(gentoo, hand, tolerance = 1e-12)))
stopifnot(abs(hand - pop) > 1e-3)
verdict("contract: ads-r-p1 counts 151/68/123, sd uses n-1 OK")
