#!/usr/bin/env bash
# shellcheck disable=SC2016
# C-M1 video 4: per-species n, mean and sample sd, checked against the n-1 formula
# shellcheck source=../lib.sh
source "$(dirname "$0")/../lib.sh"
Rscript -e 'library(agenticds)
d <- na_policy(read_penguins("datasets/penguins/penguins.csv"))
s <- summarise_by_species(d)
print(as.data.frame(s[, c("species", "n", "body_mass_g_mean", "body_mass_g_sd")]))
x <- d$body_mass_g[d$species == "Gentoo"]
hand <- sqrt(sum((x - mean(x))^2) / (length(x) - 1)); pop <- sqrt(sum((x - mean(x))^2) / length(x))
cat(sprintf("Gentoo body mass sd: summarise %.6f  n-1 by hand %.6f  n (population) %.6f\n", s$body_mass_g_sd[s$species == "Gentoo"], hand, pop))
stopifnot(s$n == c(151L, 68L, 123L), isTRUE(all.equal(s$body_mass_g_sd[s$species == "Gentoo"], hand, tolerance = 1e-12)), abs(hand - pop) > 1e-3)
cat("contract: c-m1 counts 151/68/123 and sd uses n-1 OK\n")'
