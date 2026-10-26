# C-M2 video 3 (native R): plant a slope bug; the golden-file oracle goes red. Run from the repo root.
source("demos/native-lib.R")
src <- c(
  "d <- na_policy(read_penguins(\"datasets/penguins/penguins.csv\"))",
  "g <- jsonlite::fromJSON(\"datasets/golden/p2.json\")",
  "b <- ols_closed_form(d$flipper_length_mm, d$body_mass_g)",
  "broken <- b[[\"slope\"]] + 1            # the planted bug",
  "r <- all.equal(broken, g$ols$slope, tolerance = 1e-9)",
  "!isTRUE(r)")
d <- na_policy(read_penguins("datasets/penguins/penguins.csv"))
g <- jsonlite::fromJSON("datasets/golden/p2.json")
b <- ols_closed_form(d$flipper_length_mm, d$body_mass_g)
broken <- b[["slope"]] + 1
r <- all.equal(broken, g$ols$slope, tolerance = 1e-9)
nat_show("plant a bug in the slope: the golden oracle must go red", src)
nat_row("golden slope", sprintf("%.4f", g$ols$slope))
cat(cli::col_cyan(sprintf("%-16s", "broken slope")), cli::col_red(sprintf("%.4f   %s", broken, r)), "\n", sep = "")
nat_verdict(src[6], !isTRUE(r), "contract: c-m2 broken slope is caught by the golden oracle OK")
