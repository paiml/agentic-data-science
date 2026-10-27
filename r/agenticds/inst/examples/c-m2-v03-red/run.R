# C-M2 video 3: plant a slope bug; the golden oracle goes red.
# Usage (from the repo root): source("<this file>")
library(agenticds)
d <- na_policy(read_penguins("datasets/penguins/penguins.csv"))
g <- jsonlite::fromJSON("datasets/golden/p2.json")
b <- ols_closed_form(d$flipper_length_mm, d$body_mass_g)
good <- all.equal(b[["slope"]], g$ols$slope, tolerance = 1e-9)
broken <- b[["slope"]] + 1 # the planted bug
r <- all.equal(broken, g$ols$slope, tolerance = 1e-9)
cat(sprintf("golden slope %.4f\n", g$ols$slope))
cat(sprintf("broken slope %.4f\n", broken))
cat("oracle says:", r, "\n")
stopifnot(isTRUE(good), !isTRUE(r))
verdict("contract: ads-r-p2 broken slope caught by oracle OK")
