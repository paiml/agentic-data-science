# C-M3 video 6 (native R): two planted mutants of the k-means code; the p3 tests must kill both.
source("demos/native-lib.R")
src <- c(
  "mutants <- c(scale = \"s/scale = spread)$/scale = spread * 2)/\",",
  "  dist = paste0(\"s/(z - rep(cen\\\\[k, \\\\], each = nrow(z)))^2/\",",
  "                \"abs(z - rep(cen[k, ], each = nrow(z)))/\"))",
  "killed <- sapply(mutants, nat_killed, file = \"p3.R\", filt = \"p3\")",
  "sum(killed) == 2")
mutants <- c(scale = "s/scale = spread)$/scale = spread * 2)/",
  dist = paste0("s/(z - rep(cen\\[k, \\], each = nrow(z)))^2/",
                "abs(z - rep(cen[k, ], each = nrow(z)))/"))
# The two scratch-copy test runs take a while; setup runs them once and caches the result.
cache <- file.path(Sys.getenv("HOME"), "mutants.rds")
if (!file.exists(cache)) saveRDS(sapply(mutants, nat_killed, file = "p3.R", filt = "p3"), cache)
killed <- readRDS(cache)
nat_show("two planted mutants of the k-means code: both must die", src)
nat_row("scale * 2", if (killed[[1]]) "killed" else "SURVIVED")
nat_row("abs distance", if (killed[[2]]) "killed" else "SURVIVED")
nat_verdict(src[5], sum(killed) == 2, "contract: c-m3 2 of 2 mutants killed OK")
